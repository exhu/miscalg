module device;

import std.algorithm : canFind, filter, reverse, sort;
import std.array : empty, join;
import std.conv : to;
import std.datetime : Duration, msecs;
import std.exception : collectException;
import std.file : exists;
import std.json : JSONType, JSONValue, parseJSON;
import std.process : Config, Pipe, pipe, pipeProcess, ProcessPipes, Redirect, spawnProcess, tryWait, wait;
import std.stdio : File;
import std.string : strip;
import core.thread : Thread;

struct CommandResult {
    int exitCode;
    string output;
    string error;

    bool isSuccess() const {
        return exitCode == 0;
    }
}

struct PartitionInfo {
    string name;
    string path;
    string model;
    string vendor;
    string serial;
    string size;
    string type;
    string fstype;
    string label;
    string[] mountpoints;
    int mountedCount;
    int cryptUnlockedCount;

    int totalMountedOrUnlocked() const {
        return mountedCount + cryptUnlockedCount;
    }

    string[] mountPaths;        // paths to unmount (depth-first: leaves first)
    string[] cryptLockPaths;    // paths to lock
    PartitionInfo[] children;
}

struct DiskInfo {
    string path;                // e.g. /dev/sdb
    string name;                // e.g. Samsung T7 or sdb
    string serial;              // e.g. 25074E933396 or "-"
    string size;                // e.g. 1.8T
    string type;                // e.g. disk
    bool isHotplug;
    bool isRemovable;

    int mountedCount;           // count of mounted filesystems
    int cryptUnlockedCount;     // count of unlocked LUKS containers

    int totalMountedOrUnlocked() const {
        return mountedCount + cryptUnlockedCount;
    }

    string[] mountPaths;        // paths to unmount (depth-first: leaves first)
    string[] cryptLockPaths;    // paths to lock
    PartitionInfo[] partitions; // tree of partitions
}

struct ParsedNode {
    string name;
    string path;
    string model;
    string vendor;
    string serial;
    string size;
    string type;
    string fstype;
    string label;
    bool hotplug;
    bool rm;
    string[] mountpoints;
    ParsedNode[] children;
}

private string getJsonString(JSONValue val, string key, string defaultVal = "") {
    if (val.type != JSONType.object) return defaultVal;
    if (key !in val.object) return defaultVal;
    auto item = val.object[key];
    if (item.type == JSONType.string) return item.str.strip;
    if (item.type == JSONType.integer) return item.integer.to!string;
    if (item.type == JSONType.uinteger) return item.uinteger.to!string;
    if (item.type == JSONType.true_) return "true";
    if (item.type == JSONType.false_) return "false";
    return defaultVal;
}

private bool getJsonBool(JSONValue val, string key, bool defaultVal = false) {
    if (val.type != JSONType.object) return defaultVal;
    if (key !in val.object) return defaultVal;
    auto item = val.object[key];
    if (item.type == JSONType.true_) return true;
    if (item.type == JSONType.false_) return false;
    if (item.type == JSONType.string) {
        auto s = item.str.strip;
        return (s == "1" || s == "true" || s == "yes");
    }
    if (item.type == JSONType.integer || item.type == JSONType.uinteger) {
        return item.integer != 0;
    }
    return defaultVal;
}

private string[] getJsonMountpoints(JSONValue val) {
    string[] mpts;
    if (val.type != JSONType.object) return mpts;

    if ("mountpoints" in val.object) {
        auto arr = val.object["mountpoints"];
        if (arr.type == JSONType.array) {
            foreach (elem; arr.array) {
                if (elem.type == JSONType.string && elem.str.strip.length > 0) {
                    mpts ~= elem.str.strip;
                }
            }
        }
    }
    if ("mountpoint" in val.object) {
        auto item = val.object["mountpoint"];
        if (item.type == JSONType.string && item.str.strip.length > 0) {
            auto s = item.str.strip;
            if (!mpts.canFind(s)) {
                mpts ~= s;
            }
        }
    }
    return mpts;
}

ParsedNode parseNodeFromJson(JSONValue obj) {
    ParsedNode node;
    node.name = getJsonString(obj, "name");
    node.path = getJsonString(obj, "path");
    if (node.path.empty && !node.name.empty) {
        node.path = "/dev/" ~ node.name;
    }
    node.model = getJsonString(obj, "model");
    node.vendor = getJsonString(obj, "vendor");
    node.serial = getJsonString(obj, "serial");
    node.size = getJsonString(obj, "size");
    node.type = getJsonString(obj, "type");
    node.fstype = getJsonString(obj, "fstype");
    node.label = getJsonString(obj, "label");
    node.hotplug = getJsonBool(obj, "hotplug");
    node.rm = getJsonBool(obj, "rm");
    node.mountpoints = getJsonMountpoints(obj);

    if ("children" in obj.object && obj.object["children"].type == JSONType.array) {
        foreach (childVal; obj.object["children"].array) {
            if (childVal.type == JSONType.object) {
                node.children ~= parseNodeFromJson(childVal);
            }
        }
    }
    return node;
}

void collectNodeDetails(
    ref const(ParsedNode) node,
    bool isRoot,
    ref int mountedCount,
    ref int cryptUnlockedCount,
    ref string[] mountPaths,
    ref string[] cryptLockPaths
) {
    // Process children first (depth-first)
    foreach (ref child; node.children) {
        collectNodeDetails(child, false, mountedCount, cryptUnlockedCount, mountPaths, cryptLockPaths);
    }

    // Check mountpoints
    if (node.mountpoints.length > 0) {
        bool isMounted = false;
        foreach (m; node.mountpoints) {
            if (m.length > 0 && m != "null") {
                isMounted = true;
                break;
            }
        }
        if (isMounted) {
            mountedCount++;
            if (!node.path.empty && !mountPaths.canFind(node.path)) {
                mountPaths ~= node.path;
            }
        }
    }

    // Check crypt status
    if (node.type == "crypt") {
        cryptUnlockedCount++;
        if (!node.path.empty && !cryptLockPaths.canFind(node.path)) {
            cryptLockPaths ~= node.path;
        }
    } else if (node.fstype == "crypto_LUKS" && node.children.length > 0) {
        // LUKS container that is unlocked
        if (!node.path.empty && !cryptLockPaths.canFind(node.path)) {
            cryptLockPaths ~= node.path;
        }
    }
}

PartitionInfo partitionInfoFromParsedNode(const ParsedNode node) {
    PartitionInfo part;
    part.name = node.name;
    part.path = node.path;
    part.model = node.model;
    part.vendor = node.vendor;
    part.serial = node.serial.empty ? "-" : node.serial;
    part.size = node.size;
    part.type = node.type;
    part.fstype = node.fstype;
    part.label = node.label;
    part.mountpoints = node.mountpoints.dup;

    // Depth-first collection for this partition subtree
    collectNodeDetails(node, false, part.mountedCount, part.cryptUnlockedCount, part.mountPaths, part.cryptLockPaths);

    foreach (ref child; node.children) {
        part.children ~= partitionInfoFromParsedNode(child);
    }
    return part;
}

DiskInfo diskInfoFromParsedNode(const ParsedNode rootNode) {
    DiskInfo disk;
    disk.path = rootNode.path;
    disk.serial = rootNode.serial.empty ? "-" : rootNode.serial;
    disk.size = rootNode.size;
    disk.type = rootNode.type;
    disk.isHotplug = rootNode.hotplug;
    disk.isRemovable = rootNode.rm;

    // Construct friendly name/model
    string displayName = "";
    if (!rootNode.vendor.empty && !rootNode.model.empty) {
        if (rootNode.model.canFind(rootNode.vendor)) {
            displayName = rootNode.model;
        } else {
            displayName = rootNode.vendor ~ " " ~ rootNode.model;
        }
    } else if (!rootNode.model.empty) {
        displayName = rootNode.model;
    } else if (!rootNode.vendor.empty) {
        displayName = rootNode.vendor;
    } else {
        displayName = rootNode.name;
    }
    disk.name = displayName;

    collectNodeDetails(rootNode, true, disk.mountedCount, disk.cryptUnlockedCount, disk.mountPaths, disk.cryptLockPaths);

    foreach (ref child; rootNode.children) {
        disk.partitions ~= partitionInfoFromParsedNode(child);
    }
    return disk;
}

DiskInfo[] parseLsblkJson(string jsonText) {
    DiskInfo[] result;
    if (jsonText.strip.empty) return result;

    JSONValue root;
    try {
        root = parseJSON(jsonText);
    } catch (Exception e) {
        return result;
    }

    if (root.type != JSONType.object || "blockdevices" !in root.object) {
        return result;
    }

    auto blockdevices = root.object["blockdevices"];
    if (blockdevices.type != JSONType.array) {
        return result;
    }

    foreach (devVal; blockdevices.array) {
        if (devVal.type != JSONType.object) continue;
        auto parsedNode = parseNodeFromJson(devVal);
        if (parsedNode.type == "disk") {
            result ~= diskInfoFromParsedNode(parsedNode);
        }
    }

    return result;
}

CommandResult runCommandWithBusyAnimation(
    string[] args,
    string description,
    void delegate(string desc) onBusy = null
) {
    ProcessPipes pipes;
    try {
        pipes = pipeProcess(args, Redirect.stdout | Redirect.stderr);
    } catch (Exception e) {
        return CommandResult(-1, "", e.msg);
    }

    while (!pipes.pid.tryWait().terminated) {
        if (onBusy !is null) {
            onBusy(description);
        }
        Thread.sleep(60.msecs);
    }

    auto status = pipes.pid.wait();

    string stdoutText = "";
    string stderrText = "";

    try {
        char[] buf;
        while (pipes.stdout.readln(buf)) {
            stdoutText ~= buf;
        }
    } catch (Exception e) {}

    try {
        char[] buf;
        while (pipes.stderr.readln(buf)) {
            stderrText ~= buf;
        }
    } catch (Exception e) {}

    return CommandResult(status, stdoutText.strip, stderrText.strip);
}

DiskInfo[] fetchDisks(void delegate(string desc) onBusy = null, ref string errorMsg) {
    string[] cmd = [
        "lsblk",
        "-J",
        "-o",
        "NAME,PATH,MODEL,SERIAL,HOTPLUG,RM,TYPE,MOUNTPOINTS,FSTYPE,UUID,SIZE,VENDOR,LABEL,REV"
    ];

    auto res = runCommandWithBusyAnimation(cmd, "Querying disks (lsblk)...", onBusy);
    if (!res.isSuccess) {
        errorMsg = "lsblk error: " ~ (res.error.empty ? res.output : res.error);
        return [];
    }

    auto disks = parseLsblkJson(res.output);
    return disks;
}

CommandResult unmountPartition(string devPath, void delegate(string desc) onBusy = null) {
    string[] cmd = ["udisksctl", "unmount", "-b", devPath, "--no-user-interaction"];
    return runCommandWithBusyAnimation(cmd, "Unmounting " ~ devPath ~ "...", onBusy);
}

CommandResult lockCryptoDevice(string devPath, void delegate(string desc) onBusy = null) {
    string[] cmd = ["udisksctl", "lock", "-b", devPath, "--no-user-interaction"];
    return runCommandWithBusyAnimation(cmd, "Locking " ~ devPath ~ "...", onBusy);
}

CommandResult powerOffDisk(string devPath, void delegate(string desc) onBusy = null) {
    string[] cmd = ["udisksctl", "power-off", "-b", devPath, "--no-user-interaction"];
    return runCommandWithBusyAnimation(cmd, "Powering off " ~ devPath ~ "...", onBusy);
}

struct OperationResult {
    bool success;
    string message;
}

OperationResult unmountAndLockPartition(
    string devPath,
    string[] mountPaths,
    string[] cryptLockPaths,
    void delegate(string desc) onBusy = null
) {
    if (mountPaths.empty && cryptLockPaths.empty) {
        return OperationResult(true, "Partition " ~ devPath ~ " is not mounted or unlocked.");
    }

    // 1. Unmount all mounted filesystems under this partition (depth-first: leaves first)
    foreach (mPath; mountPaths) {
        auto res = unmountPartition(mPath, onBusy);
        if (!res.isSuccess) {
            string err = res.error.empty ? res.output : res.error;
            return OperationResult(false, "Failed to unmount " ~ mPath ~ ": " ~ err);
        }
    }

    // 2. Lock all crypt mappings under this partition
    foreach (cPath; cryptLockPaths) {
        auto res = lockCryptoDevice(cPath, onBusy);
        if (!res.isSuccess) {
            string err = res.error.empty ? res.output : res.error;
            return OperationResult(false, "Failed to lock " ~ cPath ~ ": " ~ err);
        }
    }

    return OperationResult(true, "Successfully unmounted " ~ devPath ~ ".");
}

OperationResult unmountAndLockDisk(DiskInfo disk, void delegate(string desc) onBusy = null) {
    // 1. Unmount all mounted partitions
    foreach (mPath; disk.mountPaths) {
        auto res = unmountPartition(mPath, onBusy);
        if (!res.isSuccess) {
            string err = res.error.empty ? res.output : res.error;
            return OperationResult(false, "Failed to unmount " ~ mPath ~ ": " ~ err);
        }
    }

    // 2. Lock all crypt mappings
    foreach (cPath; disk.cryptLockPaths) {
        auto res = lockCryptoDevice(cPath, onBusy);
        if (!res.isSuccess) {
            string err = res.error.empty ? res.output : res.error;
            return OperationResult(false, "Failed to lock " ~ cPath ~ ": " ~ err);
        }
    }

    return OperationResult(true, "Unmounted and locked all partitions on " ~ disk.path ~ ".");
}

OperationResult powerOffDiskDevice(DiskInfo disk, void delegate(string desc) onBusy = null) {
    // First unmount and lock if anything is mounted or unlocked
    if (disk.totalMountedOrUnlocked > 0) {
        auto unmountRes = unmountAndLockDisk(disk, onBusy);
        if (!unmountRes.success) {
            return unmountRes;
        }
    }

    // Then power off
    auto pRes = powerOffDisk(disk.path, onBusy);
    if (!pRes.isSuccess) {
        string err = pRes.error.empty ? pRes.output : pRes.error;
        return OperationResult(false, "Failed to power off " ~ disk.path ~ ": " ~ err);
    }

    return OperationResult(true, "Successfully powered off " ~ disk.path ~ ".");
}

unittest {
    string sampleJson = `{
       "blockdevices": [
          {
             "name": "sdb",
             "path": "/dev/sdb",
             "model": "Ultra USB 3.0",
             "serial": "AA010928374",
             "hotplug": true,
             "rm": true,
             "type": "disk",
             "mountpoints": [ null ],
             "size": "28.8G",
             "vendor": "SanDisk",
             "children": [
                {
                   "name": "sdb1",
                   "path": "/dev/sdb1",
                   "type": "part",
                   "mountpoints": [ "/media/user/SANDISK" ],
                   "fstype": "vfat",
                   "size": "28.8G",
                   "label": "SANDISK"
                }
             ]
          },
          {
             "name": "sdc",
             "path": "/dev/sdc",
             "model": "Portable SSD",
             "serial": "1122334455",
             "hotplug": true,
             "rm": false,
             "type": "disk",
             "mountpoints": [ null ],
             "size": "500G",
             "vendor": "Samsung",
             "children": [
                {
                   "name": "sdc1",
                   "path": "/dev/sdc1",
                   "type": "part",
                   "fstype": "crypto_LUKS",
                   "mountpoints": [ null ],
                   "size": "500G",
                   "children": [
                      {
                         "name": "luks-backup",
                         "path": "/dev/mapper/luks-backup",
                         "type": "crypt",
                         "mountpoints": [ "/mnt/backup" ],
                         "fstype": "ext4",
                         "size": "500G",
                         "label": "BACKUP"
                      }
                   ]
                }
             ]
          }
       ]
    }`;

    auto disks = parseLsblkJson(sampleJson);
    assert(disks.length == 2);

    // Verify first disk (sdb)
    assert(disks[0].path == "/dev/sdb");
    assert(disks[0].name == "SanDisk Ultra USB 3.0");
    assert(disks[0].serial == "AA010928374");
    assert(disks[0].mountedCount == 1);
    assert(disks[0].cryptUnlockedCount == 0);
    assert(disks[0].totalMountedOrUnlocked == 1);
    assert(disks[0].mountPaths == ["/dev/sdb1"]);
    assert(disks[0].partitions.length == 1);
    assert(disks[0].partitions[0].name == "sdb1");
    assert(disks[0].partitions[0].path == "/dev/sdb1");
    assert(disks[0].partitions[0].fstype == "vfat");
    assert(disks[0].partitions[0].label == "SANDISK");
    assert(disks[0].partitions[0].mountpoints == ["/media/user/SANDISK"]);
    assert(disks[0].partitions[0].mountPaths == ["/dev/sdb1"]);
    assert(disks[0].partitions[0].cryptLockPaths.length == 0);

    // Verify second disk (sdc with crypto_LUKS)
    assert(disks[1].path == "/dev/sdc");
    assert(disks[1].name == "Samsung Portable SSD");
    assert(disks[1].serial == "1122334455");
    assert(disks[1].mountedCount == 1);
    assert(disks[1].cryptUnlockedCount == 1);
    assert(disks[1].totalMountedOrUnlocked == 2);
    assert(disks[1].mountPaths == ["/dev/mapper/luks-backup"]);
    assert(disks[1].cryptLockPaths == ["/dev/mapper/luks-backup", "/dev/sdc1"]);
    assert(disks[1].partitions.length == 1);
    
    auto sdc1 = disks[1].partitions[0];
    assert(sdc1.path == "/dev/sdc1");
    assert(sdc1.fstype == "crypto_LUKS");
    assert(sdc1.mountPaths == ["/dev/mapper/luks-backup"]);
    assert(sdc1.cryptLockPaths == ["/dev/mapper/luks-backup", "/dev/sdc1"]);
    assert(sdc1.children.length == 1);

    auto luksBackup = sdc1.children[0];
    assert(luksBackup.path == "/dev/mapper/luks-backup");
    assert(luksBackup.fstype == "ext4");
    assert(luksBackup.label == "BACKUP");
    assert(luksBackup.mountpoints == ["/mnt/backup"]);
    assert(luksBackup.mountPaths == ["/dev/mapper/luks-backup"]);
    assert(luksBackup.cryptLockPaths == ["/dev/mapper/luks-backup"]);

    // Test unmountAndLockPartition for non-mounted partition
    auto idleRes = unmountAndLockPartition("/dev/sdd1", [], []);
    assert(idleRes.success);
    assert(idleRes.message == "Partition /dev/sdd1 is not mounted or unlocked.");

    // Test complex LVM over LUKS
    string complexJson = `{
       "blockdevices": [
          {
             "name": "nvme0n1",
             "path": "/dev/nvme0n1",
             "model": "CT2000P310SSD8",
             "serial": "25074E933396",
             "type": "disk",
             "mountpoints": [ null ],
             "children": [
                {
                   "name": "nvme0n1p1",
                   "path": "/dev/nvme0n1p1",
                   "type": "part",
                   "mountpoints": [ "/boot" ]
                },
                {
                   "name": "nvme0n1p2",
                   "path": "/dev/nvme0n1p2",
                   "type": "part",
                   "fstype": "crypto_LUKS",
                   "mountpoints": [ null ],
                   "children": [
                      {
                         "name": "crypt_root",
                         "path": "/dev/mapper/crypt_root",
                         "type": "crypt",
                         "mountpoints": [ null ],
                         "children": [
                            {
                               "name": "vg-root",
                               "path": "/dev/mapper/vg-root",
                               "type": "lvm",
                               "mountpoints": [ "/", "/home" ]
                            },
                            {
                               "name": "vg-swap",
                               "path": "/dev/mapper/vg-swap",
                               "type": "lvm",
                               "mountpoints": [ "[SWAP]" ]
                            }
                         ]
                      }
                   ]
                }
             ]
          },
          {
             "name": "sdd",
             "path": "/dev/sdd",
             "model": null,
             "vendor": null,
             "serial": null,
             "type": "disk",
             "mountpoints": [ null ],
             "children": []
          }
       ]
    }`;

    auto complexDisks = parseLsblkJson(complexJson);
    assert(complexDisks.length == 2);

    assert(complexDisks[0].path == "/dev/nvme0n1");
    assert(complexDisks[0].name == "CT2000P310SSD8");
    assert(complexDisks[0].serial == "25074E933396");
    // Mounted: /boot, vg-root (/ and /home), vg-swap ([SWAP]) = 3 mounted devices
    assert(complexDisks[0].mountedCount == 3);
    // Unlocked crypt: crypt_root = 1
    assert(complexDisks[0].cryptUnlockedCount == 1);
    assert(complexDisks[0].totalMountedOrUnlocked == 4);
    assert(complexDisks[0].partitions.length == 2);
    assert(complexDisks[0].partitions[0].path == "/dev/nvme0n1p1");
    assert(complexDisks[0].partitions[0].mountPaths == ["/dev/nvme0n1p1"]);
    assert(complexDisks[0].partitions[1].path == "/dev/nvme0n1p2");
    assert(complexDisks[0].partitions[1].mountPaths.length == 2); // vg-swap, vg-root
    assert(complexDisks[0].partitions[1].cryptLockPaths == ["/dev/mapper/crypt_root", "/dev/nvme0n1p2"]);

    // Empty/bare unmounted disk
    assert(complexDisks[1].path == "/dev/sdd");
    assert(complexDisks[1].name == "sdd");
    assert(complexDisks[1].serial == "-");
    assert(complexDisks[1].mountedCount == 0);
    assert(complexDisks[1].cryptUnlockedCount == 0);
    assert(complexDisks[1].totalMountedOrUnlocked == 0);
    assert(complexDisks[1].partitions.length == 0);

    // Malformed JSON should return empty array safely
    assert(parseLsblkJson("").length == 0);
    assert(parseLsblkJson("{ invalid json }").length == 0);
}


