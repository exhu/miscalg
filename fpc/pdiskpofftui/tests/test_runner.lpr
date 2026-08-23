program test_runner;

{$mode objfpc}{$H+}

uses
  SysUtils, ucommon, udevice, uboxdrawing;

var
  PassedCount: Integer = 0;
  FailedCount: Integer = 0;

procedure AssertTrue(Condition: Boolean; const Msg: String);
begin
  if Condition then
  begin
    Inc(PassedCount);
  end
  else
  begin
    Inc(FailedCount);
    WriteLn(StdErr, 'ASSERTION FAILED: ', Msg);
  end;
end;

procedure AssertEquals(const Expected, Actual: String; const Msg: String);
begin
  if Expected = Actual then
  begin
    Inc(PassedCount);
  end
  else
  begin
    Inc(FailedCount);
    WriteLn(StdErr, 'ASSERTION FAILED: ', Msg, ' | Expected: "', Expected, '", got: "', Actual, '"');
  end;
end;

procedure AssertEqualsInt(Expected, Actual: Integer; const Msg: String);
begin
  if Expected = Actual then
  begin
    Inc(PassedCount);
  end
  else
  begin
    Inc(FailedCount);
    WriteLn(StdErr, 'ASSERTION FAILED: ', Msg, ' | Expected: ', Expected, ', got: ', Actual);
  end;
end;

procedure TestCommonAndUtf8;
var
  S, Padded, Trunc: String;
begin
  WriteLn('Running TestCommonAndUtf8...');

  S := '─│┌┐└┘';
  AssertEqualsInt(6, UTF8CharCount(S), 'UTF8CharCount for box drawing');
  AssertEqualsInt(18, Length(S), 'Byte length for box drawing');

  Padded := TruncateOrPad('Test', 8);
  AssertEquals('Test    ', Padded, 'TruncateOrPad padding');
  AssertEqualsInt(8, UTF8CharCount(Padded), 'Padded char count');

  Trunc := TruncateOrPad('VeryLongNameHere', 10);
  AssertEquals('VeryLon...', Trunc, 'TruncateOrPad truncation with ellipsis');
  AssertEqualsInt(10, UTF8CharCount(Trunc), 'Truncated char count');

  AssertTrue(StringArrayContains(['/dev/sda1', '/dev/sdb1'], '/dev/sdb1'), 'StringArrayContains true');
  AssertTrue(not StringArrayContains(['/dev/sda1', '/dev/sdb1'], '/dev/sdc1'), 'StringArrayContains false');
  AssertEquals('/dev/sda1, /dev/sdb1', StringArrayJoin(['/dev/sda1', '/dev/sdb1'], ', '), 'StringArrayJoin');
end;

procedure TestBoxDrawingStyles;
var
  S: TBoxStyle;
begin
  WriteLn('Running TestBoxDrawingStyles...');

  S := SingleStyle;
  AssertEquals('─', S.H, 'SingleStyle H');
  AssertEquals('│', S.V, 'SingleStyle V');
  AssertEquals('┌', S.TL, 'SingleStyle TL');
  AssertEquals('┘', S.BR, 'SingleStyle BR');

  S := DoubleStyle;
  AssertEquals('═', S.H, 'DoubleStyle H');
  AssertEquals('║', S.V, 'DoubleStyle V');
  AssertEquals('╔', S.TL, 'DoubleStyle TL');
  AssertEquals('╝', S.BR, 'DoubleStyle BR');
end;

procedure TestDeviceParsingSampleJson;
const
  SampleJson =
    '{' +
    '   "blockdevices": [' +
    '      {' +
    '         "name": "sdb",' +
    '         "path": "/dev/sdb",' +
    '         "model": "Ultra USB 3.0",' +
    '         "serial": "AA010928374",' +
    '         "hotplug": true,' +
    '         "rm": true,' +
    '         "type": "disk",' +
    '         "mountpoints": [ null ],' +
    '         "size": "28.8G",' +
    '         "vendor": "SanDisk",' +
    '         "children": [' +
    '            {' +
    '               "name": "sdb1",' +
    '               "path": "/dev/sdb1",' +
    '               "type": "part",' +
    '               "mountpoints": [ "/media/user/SANDISK" ],' +
    '               "fstype": "vfat",' +
    '               "size": "28.8G",' +
    '               "label": "SANDISK"' +
    '            }' +
    '         ]' +
    '      },' +
    '      {' +
    '         "name": "sdc",' +
    '         "path": "/dev/sdc",' +
    '         "model": "Portable SSD",' +
    '         "serial": "1122334455",' +
    '         "hotplug": true,' +
    '         "rm": false,' +
    '         "type": "disk",' +
    '         "mountpoints": [ null ],' +
    '         "size": "500G",' +
    '         "vendor": "Samsung",' +
    '         "children": [' +
    '            {' +
    '               "name": "sdc1",' +
    '               "path": "/dev/sdc1",' +
    '               "type": "part",' +
    '               "fstype": "crypto_LUKS",' +
    '               "mountpoints": [ null ],' +
    '               "size": "500G",' +
    '               "children": [' +
    '                  {' +
    '                     "name": "luks-backup",' +
    '                     "path": "/dev/mapper/luks-backup",' +
    '                     "type": "crypt",' +
    '                     "mountpoints": [ "/mnt/backup" ],' +
    '                     "fstype": "ext4",' +
    '                     "size": "500G",' +
    '                     "label": "BACKUP"' +
    '                  }' +
    '               ]' +
    '            }' +
    '         ]' +
    '      }' +
    '   ]' +
    '}';
var
  Disks: TDiskInfoArray;
  Sdc1, LuksBackup: TPartitionInfo;
  IdleRes, AllMountedRes: TOperationResult;
  CandPaths, AlreadyMntPaths: TStringArray;
begin
  WriteLn('Running TestDeviceParsingSampleJson...');

  Disks := ParseLsblkJson(SampleJson);
  AssertEqualsInt(2, Length(Disks), 'Disks length == 2');

  // Verify first disk (sdb)
  AssertEquals('/dev/sdb', Disks[0].Path, 'Disks[0].Path');
  AssertEquals('SanDisk Ultra USB 3.0', Disks[0].Name, 'Disks[0].Name');
  AssertEquals('AA010928374', Disks[0].Serial, 'Disks[0].Serial');
  AssertEqualsInt(1, Disks[0].MountedCount, 'Disks[0].MountedCount');
  AssertEqualsInt(0, Disks[0].CryptUnlockedCount, 'Disks[0].CryptUnlockedCount');
  AssertEqualsInt(1, Disks[0].TotalMountedOrUnlocked, 'Disks[0].TotalMountedOrUnlocked');
  AssertEqualsInt(1, Length(Disks[0].MountPaths), 'Disks[0].MountPaths length');
  AssertEquals('/dev/sdb1', Disks[0].MountPaths[0], 'Disks[0].MountPaths[0]');
  AssertEqualsInt(1, Length(Disks[0].Partitions), 'Disks[0].Partitions length');
  AssertEquals('sdb1', Disks[0].Partitions[0].Name, 'Disks[0].Partitions[0].Name');
  AssertEquals('/dev/sdb1', Disks[0].Partitions[0].Path, 'Disks[0].Partitions[0].Path');
  AssertEquals('vfat', Disks[0].Partitions[0].Fstype, 'Disks[0].Partitions[0].Fstype');
  AssertEquals('SANDISK', Disks[0].Partitions[0].LabelStr, 'Disks[0].Partitions[0].LabelStr');
  AssertEqualsInt(1, Length(Disks[0].Partitions[0].Mountpoints), 'Disks[0].Partitions[0].Mountpoints length');
  AssertEquals('/media/user/SANDISK', Disks[0].Partitions[0].Mountpoints[0], 'Disks[0].Partitions[0].Mountpoints[0]');
  AssertEqualsInt(0, Length(Disks[0].Partitions[0].CryptLockPaths), 'Disks[0].Partitions[0].CryptLockPaths length');

  // Verify second disk (sdc with crypto_LUKS)
  AssertEquals('/dev/sdc', Disks[1].Path, 'Disks[1].Path');
  AssertEquals('Samsung Portable SSD', Disks[1].Name, 'Disks[1].Name');
  AssertEquals('1122334455', Disks[1].Serial, 'Disks[1].Serial');
  AssertEqualsInt(1, Disks[1].MountedCount, 'Disks[1].MountedCount');
  AssertEqualsInt(1, Disks[1].CryptUnlockedCount, 'Disks[1].CryptUnlockedCount');
  AssertEqualsInt(2, Disks[1].TotalMountedOrUnlocked, 'Disks[1].TotalMountedOrUnlocked');
  AssertEqualsInt(1, Length(Disks[1].MountPaths), 'Disks[1].MountPaths length');
  AssertEquals('/dev/mapper/luks-backup', Disks[1].MountPaths[0], 'Disks[1].MountPaths[0]');
  AssertEqualsInt(2, Length(Disks[1].CryptLockPaths), 'Disks[1].CryptLockPaths length');
  AssertEquals('/dev/mapper/luks-backup', Disks[1].CryptLockPaths[0], 'Disks[1].CryptLockPaths[0]');
  AssertEquals('/dev/sdc1', Disks[1].CryptLockPaths[1], 'Disks[1].CryptLockPaths[1]');
  AssertEqualsInt(1, Length(Disks[1].Partitions), 'Disks[1].Partitions length');

  Sdc1 := Disks[1].Partitions[0];
  AssertEquals('/dev/sdc1', Sdc1.Path, 'Sdc1.Path');
  AssertEquals('crypto_LUKS', Sdc1.Fstype, 'Sdc1.Fstype');
  AssertEqualsInt(1, Length(Sdc1.MountPaths), 'Sdc1.MountPaths length');
  AssertEquals('/dev/mapper/luks-backup', Sdc1.MountPaths[0], 'Sdc1.MountPaths[0]');
  AssertEqualsInt(2, Length(Sdc1.CryptLockPaths), 'Sdc1.CryptLockPaths length');
  AssertEquals('/dev/mapper/luks-backup', Sdc1.CryptLockPaths[0], 'Sdc1.CryptLockPaths[0]');
  AssertEquals('/dev/sdc1', Sdc1.CryptLockPaths[1], 'Sdc1.CryptLockPaths[1]');
  AssertEqualsInt(1, Length(Sdc1.Children), 'Sdc1.Children length');

  LuksBackup := Sdc1.Children[0];
  AssertEquals('/dev/mapper/luks-backup', LuksBackup.Path, 'LuksBackup.Path');
  AssertEquals('ext4', LuksBackup.Fstype, 'LuksBackup.Fstype');
  AssertEquals('BACKUP', LuksBackup.LabelStr, 'LuksBackup.LabelStr');
  AssertEqualsInt(1, Length(LuksBackup.Mountpoints), 'LuksBackup.Mountpoints length');
  AssertEquals('/mnt/backup', LuksBackup.Mountpoints[0], 'LuksBackup.Mountpoints[0]');
  AssertEqualsInt(1, Length(LuksBackup.MountPaths), 'LuksBackup.MountPaths length');
  AssertEquals('/dev/mapper/luks-backup', LuksBackup.MountPaths[0], 'LuksBackup.MountPaths[0]');
  AssertEqualsInt(1, Length(LuksBackup.CryptLockPaths), 'LuksBackup.CryptLockPaths length');
  AssertEquals('/dev/mapper/luks-backup', LuksBackup.CryptLockPaths[0], 'LuksBackup.CryptLockPaths[0]');

  // Test unmountAndLockPartition for non-mounted partition
  SetLength(CandPaths, 0);
  SetLength(AlreadyMntPaths, 0);
  IdleRes := UnmountAndLockPartition('/dev/sdd1', CandPaths, AlreadyMntPaths, nil);
  AssertTrue(IdleRes.Success, 'IdleRes.Success');
  AssertEquals('Partition /dev/sdd1 is not mounted or unlocked.', IdleRes.Message, 'IdleRes.Message');

  // Test mount candidate collection for sampleJson
  CollectMountablePartitionsForDisk(Disks[0], CandPaths, AlreadyMntPaths);
  AssertEqualsInt(0, Length(CandPaths), 'Disks[0] CandPaths length');
  AssertEqualsInt(1, Length(AlreadyMntPaths), 'Disks[0] AlreadyMntPaths length');
  AssertEquals('/dev/sdb1', AlreadyMntPaths[0], 'Disks[0] AlreadyMntPaths[0]');

  AllMountedRes := MountDiskPartitions(Disks[0], nil);
  AssertTrue(AllMountedRes.Success, 'AllMountedRes.Success');
  AssertEquals('All partitions on /dev/sdb are already mounted.', AllMountedRes.Message, 'AllMountedRes.Message');

  SetLength(CandPaths, 0);
  SetLength(AlreadyMntPaths, 0);
  CollectMountablePartitionsForDisk(Disks[1], CandPaths, AlreadyMntPaths);
  AssertEqualsInt(0, Length(CandPaths), 'Disks[1] CandPaths length');
  AssertEqualsInt(1, Length(AlreadyMntPaths), 'Disks[1] AlreadyMntPaths length');
  AssertEquals('/dev/mapper/luks-backup', AlreadyMntPaths[0], 'Disks[1] AlreadyMntPaths[0]');
end;

procedure TestComplexLvmOverLuksAndSwap;
const
  ComplexJson =
    '{' +
    '   "blockdevices": [' +
    '      {' +
    '         "name": "nvme0n1",' +
    '         "path": "/dev/nvme0n1",' +
    '         "model": "CT2000P310SSD8",' +
    '         "serial": "25074E933396",' +
    '         "type": "disk",' +
    '         "mountpoints": [ null ],' +
    '         "children": [' +
    '            {' +
    '               "name": "nvme0n1p1",' +
    '               "path": "/dev/nvme0n1p1",' +
    '               "type": "part",' +
    '               "mountpoints": [ "/boot" ]' +
    '            },' +
    '            {' +
    '               "name": "nvme0n1p2",' +
    '               "path": "/dev/nvme0n1p2",' +
    '               "type": "part",' +
    '               "fstype": "crypto_LUKS",' +
    '               "mountpoints": [ null ],' +
    '               "children": [' +
    '                  {' +
    '                     "name": "crypt_root",' +
    '                     "path": "/dev/mapper/crypt_root",' +
    '                     "type": "crypt",' +
    '                     "mountpoints": [ null ],' +
    '                     "children": [' +
    '                        {' +
    '                           "name": "vg-root",' +
    '                           "path": "/dev/mapper/vg-root",' +
    '                           "type": "lvm",' +
    '                           "mountpoints": [ "/", "/home" ]' +
    '                        },' +
    '                        {' +
    '                           "name": "vg-swap",' +
    '                           "path": "/dev/mapper/vg-swap",' +
    '                           "type": "lvm",' +
    '                           "mountpoints": [ "[SWAP]" ]' +
    '                        }' +
    '                     ]' +
    '                  }' +
    '               ]' +
    '            }' +
    '         ]' +
    '      },' +
    '      {' +
    '         "name": "sdd",' +
    '         "path": "/dev/sdd",' +
    '         "model": null,' +
    '         "vendor": null,' +
    '         "serial": null,' +
    '         "type": "disk",' +
    '         "mountpoints": [ null ],' +
    '         "children": []' +
    '      }' +
    '   ]' +
    '}';
var
  ComplexDisks: TDiskInfoArray;
  CandPaths, AlreadyMntPaths: TStringArray;
begin
  WriteLn('Running TestComplexLvmOverLuksAndSwap...');

  ComplexDisks := ParseLsblkJson(ComplexJson);
  AssertEqualsInt(2, Length(ComplexDisks), 'ComplexDisks length');

  AssertEquals('/dev/nvme0n1', ComplexDisks[0].Path, 'ComplexDisks[0].Path');
  AssertEquals('CT2000P310SSD8', ComplexDisks[0].Name, 'ComplexDisks[0].Name');
  AssertEquals('25074E933396', ComplexDisks[0].Serial, 'ComplexDisks[0].Serial');
  // Mounted: /boot, vg-root (/ and /home), vg-swap ([SWAP]) = 3 mounted devices
  AssertEqualsInt(3, ComplexDisks[0].MountedCount, 'ComplexDisks[0].MountedCount');
  // Unlocked crypt: crypt_root = 1
  AssertEqualsInt(1, ComplexDisks[0].CryptUnlockedCount, 'ComplexDisks[0].CryptUnlockedCount');
  AssertEqualsInt(4, ComplexDisks[0].TotalMountedOrUnlocked, 'ComplexDisks[0].TotalMountedOrUnlocked');
  AssertEqualsInt(2, Length(ComplexDisks[0].Partitions), 'ComplexDisks[0].Partitions length');
  AssertEquals('/dev/nvme0n1p1', ComplexDisks[0].Partitions[0].Path, 'nvme0n1p1 Path');
  AssertEquals('/dev/nvme0n1p2', ComplexDisks[0].Partitions[1].Path, 'nvme0n1p2 Path');
  AssertEqualsInt(2, Length(ComplexDisks[0].Partitions[1].MountPaths), 'nvme0n1p2 MountPaths length');
  AssertEqualsInt(2, Length(ComplexDisks[0].Partitions[1].CryptLockPaths), 'nvme0n1p2 CryptLockPaths length');

  // Empty/bare unmounted disk
  AssertEquals('/dev/sdd', ComplexDisks[1].Path, 'sdd Path');
  AssertEquals('sdd', ComplexDisks[1].Name, 'sdd Name');
  AssertEquals('-', ComplexDisks[1].Serial, 'sdd Serial');
  AssertEqualsInt(0, ComplexDisks[1].MountedCount, 'sdd MountedCount');
  AssertEqualsInt(0, ComplexDisks[1].CryptUnlockedCount, 'sdd CryptUnlockedCount');
  AssertEqualsInt(0, ComplexDisks[1].TotalMountedOrUnlocked, 'sdd TotalMountedOrUnlocked');
  AssertEqualsInt(0, Length(ComplexDisks[1].Partitions), 'sdd Partitions length');

  // Test mount candidate collection for complexJson
  SetLength(CandPaths, 0);
  SetLength(AlreadyMntPaths, 0);
  CollectMountablePartitionsForDisk(ComplexDisks[0], CandPaths, AlreadyMntPaths);
  AssertEqualsInt(0, Length(CandPaths), 'nvme0n1 CandPaths length');
  AssertTrue(StringArrayContains(AlreadyMntPaths, '/dev/nvme0n1p1'), 'AlreadyMntPaths contains /boot');
  AssertTrue(StringArrayContains(AlreadyMntPaths, '/dev/mapper/vg-root'), 'AlreadyMntPaths contains vg-root');
  AssertTrue(not StringArrayContains(AlreadyMntPaths, '/dev/mapper/vg-swap'), 'AlreadyMntPaths does NOT contain vg-swap');

  // sdd has no partitions, unmounted whole disk
  SetLength(CandPaths, 0);
  SetLength(AlreadyMntPaths, 0);
  CollectMountablePartitionsForDisk(ComplexDisks[1], CandPaths, AlreadyMntPaths);
  AssertEqualsInt(1, Length(CandPaths), 'sdd CandPaths length');
  AssertEquals('/dev/sdd', CandPaths[0], 'sdd CandPaths[0]');
end;

procedure TestSwapExclusion;
const
  SwapJson =
    '{' +
    '   "blockdevices": [' +
    '      {' +
    '         "name": "sde",' +
    '         "path": "/dev/sde",' +
    '         "model": "Flash Drive",' +
    '         "serial": "998877",' +
    '         "type": "disk",' +
    '         "mountpoints": [ null ],' +
    '         "children": [' +
    '            {' +
    '               "name": "sde1",' +
    '               "path": "/dev/sde1",' +
    '               "type": "part",' +
    '               "fstype": "ext4",' +
    '               "mountpoints": [ null ]' +
    '            },' +
    '            {' +
    '               "name": "sde2",' +
    '               "path": "/dev/sde2",' +
    '               "type": "part",' +
    '               "fstype": "swap",' +
    '               "mountpoints": [ null ]' +
    '            },' +
    '            {' +
    '               "name": "sde3",' +
    '               "path": "/dev/sde3",' +
    '               "type": "part",' +
    '               "fstype": "vfat",' +
    '               "mountpoints": [ null ]' +
    '            }' +
    '         ]' +
    '      }' +
    '   ]' +
    '}';
  OnlySwapJson =
    '{' +
    '   "blockdevices": [' +
    '      {' +
    '         "name": "sdf",' +
    '         "path": "/dev/sdf",' +
    '         "model": "Swap Drive",' +
    '         "serial": "12345",' +
    '         "type": "disk",' +
    '         "mountpoints": [ null ],' +
    '         "children": [' +
    '            {' +
    '               "name": "sdf1",' +
    '               "path": "/dev/sdf1",' +
    '               "type": "part",' +
    '               "fstype": "swap",' +
    '               "mountpoints": [ null ]' +
    '            }' +
    '         ]' +
    '      }' +
    '   ]' +
    '}';
var
  SwapDisks, OnlySwapDisks: TDiskInfoArray;
  CandPaths, AlreadyMntPaths: TStringArray;
  NoMountableRes: TOperationResult;
begin
  WriteLn('Running TestSwapExclusion...');

  SwapDisks := ParseLsblkJson(SwapJson);
  AssertEqualsInt(1, Length(SwapDisks), 'SwapDisks length');
  SetLength(CandPaths, 0);
  SetLength(AlreadyMntPaths, 0);
  CollectMountablePartitionsForDisk(SwapDisks[0], CandPaths, AlreadyMntPaths);
  // Should include sde1 and sde3, but NOT sde2 (swap)
  AssertEqualsInt(2, Length(CandPaths), 'CandPaths length for swap disk');
  AssertEquals('/dev/sde1', CandPaths[0], 'CandPaths[0]');
  AssertEquals('/dev/sde3', CandPaths[1], 'CandPaths[1]');
  AssertEqualsInt(0, Length(AlreadyMntPaths), 'AlreadyMntPaths length');

  // Test disk with only swap partition
  OnlySwapDisks := ParseLsblkJson(OnlySwapJson);
  AssertEqualsInt(1, Length(OnlySwapDisks), 'OnlySwapDisks length');
  NoMountableRes := MountDiskPartitions(OnlySwapDisks[0], nil);
  AssertTrue(NoMountableRes.Success, 'NoMountableRes.Success');
  AssertEquals('No mountable partitions found on /dev/sdf.', NoMountableRes.Message, 'NoMountableRes.Message');

  // Malformed JSON should return empty array safely
  AssertEqualsInt(0, Length(ParseLsblkJson('')), 'Empty JSON');
  AssertEqualsInt(0, Length(ParseLsblkJson('{ invalid json }')), 'Invalid JSON');
end;

begin
  WriteLn('=== Running diskpoff-tui Free Pascal Test Suite ===');
  TestCommonAndUtf8;
  TestBoxDrawingStyles;
  TestDeviceParsingSampleJson;
  TestComplexLvmOverLuksAndSwap;
  TestSwapExclusion;

  WriteLn('==================================================');
  WriteLn(Format('Results: %d passed, %d failed.', [PassedCount, FailedCount]));
  if FailedCount > 0 then
    Halt(1);
end.
