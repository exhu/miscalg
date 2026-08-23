module ui;

import std.algorithm : canFind, clamp, max, min;
import std.array : empty, join, replicate;
import std.conv : to;
import std.format : format;
import std.string : leftJustifier, strip;
import std.utf : count, toUTF32;
import arsd.terminal;
import device;
import boxdrawing;

enum StatusType {
    pending,
    success,
    error
}

enum RowType {
    device,
    partition
}

struct UiRow {
    RowType type;
    size_t diskIndex;           // Index into disks[]
    string diskPath;            // Parent disk path, e.g. /dev/sdb
    string devPath;             // Node device path, e.g. /dev/sdb or /dev/sdb1
    string treePrefix;          // Prefix for device column
    string devCol;              // Full formatted device column text
    string nameCol;             // Model / Name column text
    string serialCol;           // Serial column text
    string mntCol;              // Mounted / Crypt column text

    string[] mountPaths;        // Paths to unmount for this item subtree
    string[] cryptLockPaths;    // Paths to lock for this item subtree
    bool isExpanded;            // Only for RowType.device
}

struct TuiApp {
    Terminal* terminal;
    RealTimeConsoleInput* input;

    DiskInfo[] disks;
    bool[string] expandedDisks;
    UiRow[] visibleRows;

    size_t selectedIndex = 0;
    size_t scrollOffset = 0;

    string statusMessage = "Ready. J/K: Select | Enter: Expand/Collapse | M: Mount | U: Unmount | P: Poweroff | Q: Quit";
    StatusType statusType = StatusType.success;

    private int spinnerFrame = 0;
    private static immutable string[] spinnerChars = ["|", "/", "-", "\\"];

    this(Terminal* term, RealTimeConsoleInput* inStream) {
        this.terminal = term;
        this.input = inStream;
    }

    void onBusy(string taskDesc) {
        spinnerFrame = (spinnerFrame + 1) % cast(int) spinnerChars.length;
        statusMessage = "[" ~ spinnerChars[spinnerFrame] ~ "] " ~ taskDesc;
        statusType = StatusType.pending;
        drawStatusLine();
        terminal.flush();
    }

    private void flattenPartitions(
        const ref PartitionInfo[] parts,
        size_t diskIdx,
        string diskPath,
        string prefix,
        ref UiRow[] rows
    ) {
        for (size_t i = 0; i < parts.length; i++) {
            bool isLast = (i + 1 == parts.length);
            string branch = isLast ? "└─ " : "├─ ";
            string rowPrefix = prefix ~ branch;
            string childPrefix = prefix ~ (isLast ? "   " : "│  ");

            UiRow row;
            row.type = RowType.partition;
            row.diskIndex = diskIdx;
            row.diskPath = diskPath;
            row.devPath = parts[i].path;
            row.treePrefix = rowPrefix;
            row.devCol = rowPrefix ~ parts[i].path;

            // Model / Name column:
            string nameDetail = "";
            if (!parts[i].label.empty) {
                nameDetail = parts[i].label;
                if (!parts[i].fstype.empty || !parts[i].size.empty) {
                    nameDetail ~= " (";
                    if (!parts[i].fstype.empty) nameDetail ~= parts[i].fstype;
                    if (!parts[i].fstype.empty && !parts[i].size.empty) nameDetail ~= ", ";
                    if (!parts[i].size.empty) nameDetail ~= parts[i].size;
                    nameDetail ~= ")";
                }
            } else if (!parts[i].fstype.empty) {
                nameDetail = parts[i].fstype;
                if (!parts[i].size.empty) {
                    nameDetail ~= " (" ~ parts[i].size ~ ")";
                }
            } else if (!parts[i].size.empty) {
                nameDetail = parts[i].size;
            } else {
                nameDetail = "-";
            }
            row.nameCol = " " ~ nameDetail;

            // Serial column:
            row.serialCol = " -";

            // Mounted / Crypt column:
            string mntDetail = "";
            if (parts[i].mountpoints.length > 0) {
                mntDetail = parts[i].mountpoints.join(", ");
            } else if (parts[i].type == "crypt" || (parts[i].fstype == "crypto_LUKS" && parts[i].children.length > 0)) {
                mntDetail = "[unlocked]";
            } else if (parts[i].fstype == "crypto_LUKS") {
                mntDetail = "[locked]";
            } else {
                mntDetail = "[unmounted]";
            }
            row.mntCol = " " ~ mntDetail;

            row.mountPaths = parts[i].mountPaths.dup;
            row.cryptLockPaths = parts[i].cryptLockPaths.dup;
            row.isExpanded = false;

            rows ~= row;

            if (parts[i].children.length > 0) {
                flattenPartitions(parts[i].children, diskIdx, diskPath, childPrefix, rows);
            }
        }
    }

    void rebuildVisibleRows() {
        visibleRows = [];
        if (disks.length == 0) {
            selectedIndex = 0;
            return;
        }

        foreach (dIdx, ref disk; disks) {
            bool isExp = expandedDisks.get(disk.path, false);

            UiRow devRow;
            devRow.type = RowType.device;
            devRow.diskIndex = dIdx;
            devRow.diskPath = disk.path;
            devRow.devPath = disk.path;
            devRow.treePrefix = " ";
            devRow.devCol = " " ~ disk.path;
            devRow.nameCol = " " ~ disk.name;
            devRow.serialCol = " " ~ disk.serial;

            if (disk.totalMountedOrUnlocked == 0) {
                devRow.mntCol = " 0";
            } else {
                devRow.mntCol = format(" %d (%d mnt, %d crypt)",
                    disk.totalMountedOrUnlocked, disk.mountedCount, disk.cryptUnlockedCount);
            }
            devRow.mountPaths = disk.mountPaths.dup;
            devRow.cryptLockPaths = disk.cryptLockPaths.dup;
            devRow.isExpanded = isExp;

            visibleRows ~= devRow;

            if (isExp && disk.partitions.length > 0) {
                flattenPartitions(disk.partitions, dIdx, disk.path, " ", visibleRows);
            }
        }

        if (selectedIndex >= visibleRows.length && visibleRows.length > 0) {
            selectedIndex = visibleRows.length - 1;
        }
    }

    void refreshDisks(bool preserveStatus = false) {
        auto prevMessage = statusMessage;
        auto prevType = statusType;

        string errorMsg;
        auto fetched = fetchDisks(&this.onBusy, errorMsg);
        if (!errorMsg.empty) {
            statusMessage = errorMsg;
            statusType = StatusType.error;
        } else {
            disks = fetched;
            rebuildVisibleRows();
            if (preserveStatus) {
                statusMessage = prevMessage;
                statusType = prevType;
            } else {
                statusMessage = format("Disks refreshed (%d device%s found).", disks.length, disks.length == 1 ? "" : "s");
                statusType = StatusType.success;
            }
        }
    }

    void moveUp() {
        if (visibleRows.length == 0) return;
        if (selectedIndex > 0) {
            selectedIndex--;
        }
    }

    void moveDown() {
        if (visibleRows.length == 0) return;
        if (selectedIndex + 1 < visibleRows.length) {
            selectedIndex++;
        }
    }

    void handleEnter() {
        if (visibleRows.length == 0 || selectedIndex >= visibleRows.length) return;
        auto row = visibleRows[selectedIndex];

        if (row.type == RowType.device) {
            bool curExp = expandedDisks.get(row.diskPath, false);
            expandedDisks[row.diskPath] = !curExp;
            rebuildVisibleRows();
            
            if (!curExp && disks[row.diskIndex].partitions.length == 0) {
                statusMessage = format("Device %s expanded (no partitions).", row.diskPath);
            } else {
                statusMessage = format("Device %s %s.", row.diskPath, !curExp ? "expanded" : "collapsed");
            }
            statusType = StatusType.success;
        }
    }

    void handleMount() {
        if (visibleRows.length == 0 || selectedIndex >= visibleRows.length) return;
        auto row = visibleRows[selectedIndex];

        if (row.type == RowType.device) {
            auto disk = disks[row.diskIndex];
            auto res = mountDiskPartitions(disk, &this.onBusy);
            if (res.success) {
                statusMessage = res.message;
                statusType = StatusType.success;
            } else {
                statusMessage = res.message;
                statusType = StatusType.error;
            }
        } else {
            // Partition selected
            if (row.mountPaths.canFind(row.devPath)) {
                statusMessage = format("Partition %s is already mounted.", row.devPath);
                statusType = StatusType.success;
                return;
            }

            auto res = mountSinglePartition(row.devPath, &this.onBusy);
            if (res.success) {
                statusMessage = res.message;
                statusType = StatusType.success;
            } else {
                statusMessage = res.message;
                statusType = StatusType.error;
            }
        }
        refreshDisks(true);
    }

    void handleUnmountOnly() {
        if (visibleRows.length == 0 || selectedIndex >= visibleRows.length) return;
        auto row = visibleRows[selectedIndex];

        if (row.type == RowType.device) {
            auto disk = disks[row.diskIndex];
            if (disk.totalMountedOrUnlocked == 0) {
                statusMessage = format("Device %s has no mounted partitions or unlocked containers.", disk.path);
                statusType = StatusType.success;
                return;
            }

            auto res = unmountAndLockDisk(disk, &this.onBusy);
            if (res.success) {
                statusMessage = res.message;
                statusType = StatusType.success;
            } else {
                statusMessage = res.message;
                statusType = StatusType.error;
            }
        } else {
            // Partition selected
            if (row.mountPaths.length == 0 && row.cryptLockPaths.length == 0) {
                statusMessage = format("Partition %s is not mounted or unlocked.", row.devPath);
                statusType = StatusType.success;
                return;
            }

            auto res = unmountAndLockPartition(row.devPath, row.mountPaths, row.cryptLockPaths, &this.onBusy);
            if (res.success) {
                statusMessage = res.message;
                statusType = StatusType.success;
            } else {
                statusMessage = res.message;
                statusType = StatusType.error;
            }
        }
        refreshDisks(true);
    }

    void handlePowerOff() {
        if (visibleRows.length == 0 || selectedIndex >= visibleRows.length) return;
        auto row = visibleRows[selectedIndex];

        // Power off the parent device even when an individual partition is selected
        auto parentDisk = disks[row.diskIndex];

        auto res = powerOffDiskDevice(parentDisk, &this.onBusy);
        if (res.success) {
            statusMessage = res.message;
            statusType = StatusType.success;
        } else {
            statusMessage = res.message;
            statusType = StatusType.error;
        }
        refreshDisks(true);
    }

    private string truncateOrPad(string s, int width) {
        if (width <= 0) return "";
        auto charCount = s.toUTF32().length;
        if (charCount > width) {
            if (width > 3) {
                return s.toUTF32()[0 .. width - 3].to!string ~ "...";
            } else {
                return s.toUTF32()[0 .. width].to!string;
            }
        }
        int padding = width - cast(int) charCount;
        return s ~ " ".replicate(padding);
    }

    struct ColumnLayout {
	int dev;
	int name;
	int serial;
	int mnt;

	static ColumnLayout calculate(int totalWidth) {
	    int dev = max(16, min(32, totalWidth * 25 / 100));
	    int serial = max(12, min(20, totalWidth * 18 / 100));
	    int mnt = max(18, min(35, totalWidth * 28 / 100));

	    // 3 separators + 2 border columns = 5 consumed width units
	    int name = totalWidth - 2 - (dev + serial + mnt + 3);
	    if (name < 12) {
		name = 12;
		dev = max(10, totalWidth - 2 - (name + serial + mnt + 3));
	    }

	    return ColumnLayout(dev, name, serial, mnt);
	}
    }

    void draw() {
	const int w = terminal.width;
	const int h = terminal.height;

	// Reset base background
	terminal.color(Color.white, Color.blue);
	terminal.clear();

	if (w < 20 || h < 6) {
	    terminal.moveTo(0, 0);
	    terminal.write("Window too small");
	    drawStatusLine();
	    terminal.flush();
	    return;
	}

	const int frameTop = 1;
	const int frameBottom = h - 2;
	const int innerHeight = max(1, (frameBottom - frameTop + 1) - 4);

	auto cols = ColumnLayout.calculate(w);

	updateScrollOffset(innerHeight);

	drawTitleBar(w);
	drawTableFrame(w, frameTop, cols);
	drawDataRows(w, frameTop + 3, innerHeight, cols);

	// Bottom border
	terminal.moveTo(0, frameBottom);
	terminal.color(Color.white, Color.blue);
	terminal.write(doubleStyle.bl ~ doubleStyle.h.replicate(w - 2) ~ doubleStyle.br);

	drawStatusLine();
	terminal.flush();
    }

    private void drawTitleBar(int width) {
	const string title = " Removable Disks Manager (diskpoff-tui) ";
	const string helpTop = "[ J/K: Nav | Enter: Expand/Collapse | M: Mount | U: Unmount | P: Poweroff | R: Refresh | Q: Quit ] ";
	const int spaceBetween = max(0, width - cast(int)title.length - cast(int)helpTop.length);

	terminal.moveTo(0, 0);
	terminal.color(Color.white | Bright, Color.blue);
	terminal.write(title ~ " ".replicate(spaceBetween) ~ helpTop);
    }

    private void drawTableFrame(int width, int top, in ColumnLayout cols) {
	// 1. Top border with column splitters (╦)
	terminal.moveTo(0, top);
	terminal.color(Color.white, Color.blue);
	terminal.write(
	    doubleStyle.tl ~
	    doubleStyle.h.replicate(cols.dev)    ~ doubleHorizSingleVertStyle.tDown ~
	    doubleStyle.h.replicate(cols.name)   ~ doubleHorizSingleVertStyle.tDown ~
	    doubleStyle.h.replicate(cols.serial) ~ doubleHorizSingleVertStyle.tDown ~
	    doubleStyle.h.replicate(cols.mnt)    ~
	    doubleStyle.tr
	);

	// 2. Header row
	terminal.moveTo(0, top + 1);
	terminal.write(doubleStyle.v);

	void writeHeaderCell(string label, int colWidth, bool isLast = false) {
	    terminal.color(Color.white | Bright, Color.blue);
	    terminal.write(truncateOrPad(label, colWidth));
	    terminal.color(Color.white, Color.blue);
	    terminal.write(isLast ? doubleStyle.v : singleStyle.v);
	}

	writeHeaderCell(" Device", cols.dev);
	writeHeaderCell(" Model / Name", cols.name);
	writeHeaderCell(" Serial", cols.serial);
	writeHeaderCell(" Mounted / Crypt", cols.mnt, true);

	// 3. Header separator with column splitters (╩)
	terminal.moveTo(0, top + 2);
	terminal.write(
	    doubleStyle.tRight ~
	    doubleStyle.h.replicate(cols.dev)    ~ doubleHorizSingleVertStyle.cross ~
	    doubleStyle.h.replicate(cols.name)   ~ doubleHorizSingleVertStyle.cross ~
	    doubleStyle.h.replicate(cols.serial) ~ doubleHorizSingleVertStyle.cross ~
	    doubleStyle.h.replicate(cols.mnt)    ~
	    doubleStyle.tLeft
	);
    }

    private void drawDataRows(int width, int startY, int rowCount, in ColumnLayout cols) {
	for (int row = 0; row < rowCount; row++) {
	    const int curY = startY + row;
	    const size_t visibleIdx = scrollOffset + row;

	    terminal.moveTo(0, curY);
	    terminal.color(Color.white, Color.blue);
	    terminal.write(doubleStyle.v);

	    if (visibleRows.length == 0) {
		string msg = (row == 0) ? "  (No active disk devices found. Press R to refresh)" : "";
		terminal.write(truncateOrPad(msg, width - 2));
	    } else if (visibleIdx < visibleRows.length) {
		renderDataRow(visibleRows[visibleIdx], visibleIdx == selectedIndex, cols, width);
	    } else {
		terminal.write(" ".replicate(width - 2));
	    }

	    terminal.moveTo(width - 1, curY);
	    terminal.color(Color.white, Color.blue);
	    terminal.write(doubleStyle.v);
	}
    }

    private void renderDataRow(in typeof(visibleRows[0]) item, bool isSelected, in ColumnLayout cols, int totalWidth) {
	terminal.color(isSelected ? Color.blue : Color.white, 
		    isSelected ? Color.white : Color.blue);

	string lineText = truncateOrPad(item.devCol, cols.dev) ~ singleStyle.v ~
			truncateOrPad(item.nameCol, cols.name) ~ singleStyle.v ~
			truncateOrPad(item.serialCol, cols.serial) ~ singleStyle.v ~
			truncateOrPad(item.mntCol, cols.mnt);

	terminal.write(truncateOrPad(lineText, totalWidth - 2));
	terminal.color(Color.white, Color.blue);
    }

    private void updateScrollOffset(int viewHeight) {
	if (selectedIndex < scrollOffset) {
	    scrollOffset = selectedIndex;
	} else if (selectedIndex >= scrollOffset + viewHeight) {
	    scrollOffset = selectedIndex - viewHeight + 1;
	}
    }

    void drawStatusLine() {
        int w = terminal.width;
        int h = terminal.height;
        if (h <= 0 || w <= 0) return;

        terminal.moveTo(0, h - 1);

        if (statusType == StatusType.error) {
            // Red background, white text
            terminal.color(Color.white | Bright, Color.red);
        } else {
            // Green background, yellow text
            terminal.color(Color.yellow | Bright, Color.green);
        }

        string msg = " " ~ statusMessage;
        terminal.write(truncateOrPad(msg, w));
        terminal.color(Color.white, Color.blue);
    }

	    void run() {
	    refreshDisks();
	draw();

	while (processNextEvent()) {
	    // Continue processing loop
	}
    }

    private bool processNextEvent() {
	auto event = input.nextEvent();

	// Check for exit / termination events
	if (event.type == InputEvent.Type.UserInterruptionEvent ||
	    event.type == InputEvent.Type.HangupEvent ||
	    event.type == InputEvent.Type.EndOfFileEvent) {
	    return false;
	}

	// Terminal resize
	if (event.type == InputEvent.Type.SizeChangedEvent) {
	    draw();
	    return true;
	}

	// Keyboard handling
	if (event.type == InputEvent.Type.KeyboardEvent) {
	    auto kEvent = event.get!(InputEvent.Type.KeyboardEvent);
	    if (kEvent.pressed) {
		return handleKeyEvent(kEvent.which);
	    }
	}

	return true;
    }

    private bool handleKeyEvent(typeof(KeyboardEvent.which) key) {
	bool shouldRedraw = true;

	switch (key) {
	    // Exit
	    case 'q':
	    case 'Q':
	    case KeyboardEvent.Key.escape:
		return false;

	    // Navigation
	    case 'j':
	    case 'J':
	    case KeyboardEvent.Key.DownArrow:
		moveDown();
		break;

	    case 'k':
	    case 'K':
	    case KeyboardEvent.Key.UpArrow:
		moveUp();
		break;

	    case KeyboardEvent.Key.PageDown:
		pageDown();
		break;

	    case KeyboardEvent.Key.PageUp:
		pageUp();
		break;

	    case KeyboardEvent.Key.Home:
		jumpToStart();
		break;

	    case KeyboardEvent.Key.End:
		jumpToEnd();
		break;

	    // Actions
	    case '\r':
	    case '\n':
		handleEnter();
		break;

	    case 'u':
	    case 'U':
		handleUnmountOnly();
		break;

	    case 'm':
	    case 'M':
		handleMount();
		break;

	    case 'p':
	    case 'P':
		handlePowerOff();
		break;

	    case 'r':
	    case 'R':
		refreshDisks();
		break;

	    default:
		shouldRedraw = false;
		break;
	}

	if (shouldRedraw) {
	    draw();
	}

	return true;
    }

    private int getPageStep() {
	import std.algorithm.comparison : max;
	return max(1, terminal.height - 6);
    }

    private void pageDown() {
	const step = getPageStep();
	foreach (_; 0 .. step) {
	    moveDown();
	}
    }

    private void pageUp() {
	const step = getPageStep();
	foreach (_; 0 .. step) {
	    moveUp();
	}
    }

    private void jumpToStart() {
	selectedIndex = 0;
    }

    private void jumpToEnd() {
	if (visibleRows.length > 0) {
	    selectedIndex = visibleRows.length - 1;
	}
    }
}
