module ui;

import std.algorithm : clamp, max, min;
import std.array : empty, replicate;
import std.conv : to;
import std.format : format;
import std.string : leftJustifier, strip;
import std.utf : count, toUTF32;
import arsd.terminal;
import device;

enum StatusType {
    pending,
    success,
    error
}

struct TuiApp {
    Terminal* terminal;
    RealTimeConsoleInput* input;

    DiskInfo[] disks;
    size_t selectedIndex = 0;
    size_t scrollOffset = 0;

    string statusMessage = "Ready. J/K/Up/Down: Select | Enter: Unmount/Poweroff | U: Unmount | P: Poweroff | Q: Quit";
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

    void refreshDisks() {
        string errorMsg;
        auto fetched = fetchDisks(&this.onBusy, errorMsg);
        if (!errorMsg.empty) {
            statusMessage = errorMsg;
            statusType = StatusType.error;
        } else {
            disks = fetched;
            if (selectedIndex >= disks.length && disks.length > 0) {
                selectedIndex = disks.length - 1;
            }
            statusMessage = format("Disks refreshed (%d device%s found).", disks.length, disks.length == 1 ? "" : "s");
            statusType = StatusType.success;
        }
    }

    void moveUp() {
        if (disks.length == 0) return;
        if (selectedIndex > 0) {
            selectedIndex--;
        }
    }

    void moveDown() {
        if (disks.length == 0) return;
        if (selectedIndex + 1 < disks.length) {
            selectedIndex++;
        }
    }

    void handleEnter() {
        if (disks.length == 0 || selectedIndex >= disks.length) return;
        auto disk = disks[selectedIndex];

        if (disk.totalMountedOrUnlocked > 0) {
            // Unmount and lock
            auto res = unmountAndLockDisk(disk, &this.onBusy);
            if (res.success) {
                statusMessage = res.message;
                statusType = StatusType.success;
            } else {
                statusMessage = res.message;
                statusType = StatusType.error;
            }
        } else {
            // Power off
            auto res = powerOffDiskDevice(disk, &this.onBusy);
            if (res.success) {
                statusMessage = res.message;
                statusType = StatusType.success;
            } else {
                statusMessage = res.message;
                statusType = StatusType.error;
            }
        }
        refreshDisks();
    }

    void handleUnmountOnly() {
        if (disks.length == 0 || selectedIndex >= disks.length) return;
        auto disk = disks[selectedIndex];

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
        refreshDisks();
    }

    void handlePowerOff() {
        if (disks.length == 0 || selectedIndex >= disks.length) return;
        auto disk = disks[selectedIndex];

        auto res = powerOffDiskDevice(disk, &this.onBusy);
        if (res.success) {
            statusMessage = res.message;
            statusType = StatusType.success;
        } else {
            statusMessage = res.message;
            statusType = StatusType.error;
        }
        refreshDisks();
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

    void draw() {
        int w = terminal.width;
        int h = terminal.height;

        if (w < 20 || h < 6) {
            terminal.color(Color.white, Color.blue);
            terminal.clear();
            terminal.moveTo(0, 0);
            terminal.write("Window too small");
            drawStatusLine();
            terminal.flush();
            return;
        }

        // Fill background with dark blue
        terminal.color(Color.white, Color.blue);
        terminal.clear();

        // Title line at row 0
        terminal.moveTo(0, 0);
        string title = " Removable Disks Manager (diskpoff-tui) ";
        string helpTop = "[ J/K: Nav | Enter: Action | U: Unmount | P: Poweroff | R: Refresh | Q: Quit ] ";
        int spaceBetween = max(0, w - cast(int) title.length - cast(int) helpTop.length);
        terminal.color(Color.white | Bright, Color.blue);
        terminal.write(title ~ " ".replicate(spaceBetween) ~ helpTop);

        // Frame parameters
        int frameTop = 1;
        int frameBottom = h - 2;
        int frameHeight = frameBottom - frameTop + 1;
        int innerHeight = frameHeight - 4; // top border, header row, header separator, bottom border

        if (innerHeight < 1) innerHeight = 1;

        // Calculate columns
        int devWidth = 14;
        int serialWidth = 16;
        int mntWidth = 20;
        int nameWidth = w - 2 - (devWidth + serialWidth + mntWidth + 3); // 3 vertical column separators
        if (nameWidth < 10) {
            nameWidth = 10;
            devWidth = max(8, w - 2 - (nameWidth + serialWidth + mntWidth + 3));
        }

        // 1. Top border
        terminal.moveTo(0, frameTop);
        terminal.color(Color.white, Color.blue);
        terminal.write("+" ~ "-".replicate(w - 2) ~ "+");

        // 2. Header row
        terminal.moveTo(0, frameTop + 1);
        terminal.write("|");
        terminal.color(Color.white | Bright, Color.blue);
        terminal.write(truncateOrPad(" Device", devWidth));
        terminal.color(Color.white, Color.blue);
        terminal.write("|");
        terminal.color(Color.white | Bright, Color.blue);
        terminal.write(truncateOrPad(" Model / Name", nameWidth));
        terminal.color(Color.white, Color.blue);
        terminal.write("|");
        terminal.color(Color.white | Bright, Color.blue);
        terminal.write(truncateOrPad(" Serial", serialWidth));
        terminal.color(Color.white, Color.blue);
        terminal.write("|");
        terminal.color(Color.white | Bright, Color.blue);
        terminal.write(truncateOrPad(" Mounted / Crypt", mntWidth));
        terminal.color(Color.white, Color.blue);
        terminal.write("|");

        // 3. Header separator
        terminal.moveTo(0, frameTop + 2);
        terminal.write("+" ~ "-".replicate(w - 2) ~ "+");

        // Adjust scrollOffset
        if (selectedIndex < scrollOffset) {
            scrollOffset = selectedIndex;
        } else if (selectedIndex >= scrollOffset + innerHeight) {
            scrollOffset = selectedIndex - innerHeight + 1;
        }

        // 4. Data rows
        for (int row = 0; row < innerHeight; row++) {
            int curY = frameTop + 3 + row;
            size_t diskIdx = scrollOffset + row;
            terminal.moveTo(0, curY);

            terminal.color(Color.white, Color.blue);
            terminal.write("|");

            if (disks.length == 0) {
                if (row == 0) {
                    string emptyMsg = "  (No active disk devices found. Press R to refresh)";
                    terminal.write(truncateOrPad(emptyMsg, w - 2));
                } else {
                    terminal.write(" ".replicate(w - 2));
                }
            } else if (diskIdx < disks.length) {
                auto disk = disks[diskIdx];
                bool isSelected = (diskIdx == selectedIndex);

                string devStr = " " ~ disk.path;
                string nameStr = " " ~ disk.name;
                string serialStr = " " ~ disk.serial;
                
                string mntDetail;
                if (disk.totalMountedOrUnlocked == 0) {
                    mntDetail = " 0";
                } else {
                    mntDetail = format(" %d (%d mnt, %d crypt)", 
                        disk.totalMountedOrUnlocked, disk.mountedCount, disk.cryptUnlockedCount);
                }

                if (isSelected) {
                    // Inverted selection: blue on white
                    terminal.color(Color.blue, Color.white);
                } else {
                    terminal.color(Color.white, Color.blue);
                }

                string lineText = truncateOrPad(devStr, devWidth) ~ "|" ~
                                  truncateOrPad(nameStr, nameWidth) ~ "|" ~
                                  truncateOrPad(serialStr, serialWidth) ~ "|" ~
                                  truncateOrPad(mntDetail, mntWidth);
                
                terminal.write(truncateOrPad(lineText, w - 2));
                terminal.color(Color.white, Color.blue);
            } else {
                terminal.write(" ".replicate(w - 2));
            }

            terminal.moveTo(w - 1, curY);
            terminal.color(Color.white, Color.blue);
            terminal.write("|");
        }

        // 5. Bottom border
        terminal.moveTo(0, frameBottom);
        terminal.color(Color.white, Color.blue);
        terminal.write("+" ~ "-".replicate(w - 2) ~ "+");

        // 6. Status line
        drawStatusLine();

        terminal.flush();
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

        bool running = true;
        while (running) {
            auto event = input.nextEvent();
            if (event.type == InputEvent.Type.UserInterruptionEvent ||
                event.type == InputEvent.Type.HangupEvent ||
                event.type == InputEvent.Type.EndOfFileEvent) {
                break;
            }

            if (event.type == InputEvent.Type.SizeChangedEvent) {
                draw();
                continue;
            }

            if (event.type == InputEvent.Type.KeyboardEvent) {
                auto kEvent = event.get!(InputEvent.Type.KeyboardEvent);
                if (!kEvent.pressed) continue;

                auto key = kEvent.which;

                if (key == 'q' || key == 'Q' || key == KeyboardEvent.Key.escape) {
                    running = false;
                } else if (key == 'j' || key == 'J' || key == KeyboardEvent.Key.DownArrow) {
                    moveDown();
                    draw();
                } else if (key == 'k' || key == 'K' || key == KeyboardEvent.Key.UpArrow) {
                    moveUp();
                    draw();
                } else if (key == KeyboardEvent.Key.PageDown) {
                    int step = max(1, terminal.height - 6);
                    for (int i = 0; i < step; i++) moveDown();
                    draw();
                } else if (key == KeyboardEvent.Key.PageUp) {
                    int step = max(1, terminal.height - 6);
                    for (int i = 0; i < step; i++) moveUp();
                    draw();
                } else if (key == KeyboardEvent.Key.Home) {
                    selectedIndex = 0;
                    draw();
                } else if (key == KeyboardEvent.Key.End) {
                    if (disks.length > 0) selectedIndex = disks.length - 1;
                    draw();
                } else if (key == '\r' || key == '\n') {
                    handleEnter();
                    draw();
                } else if (key == 'u' || key == 'U') {
                    handleUnmountOnly();
                    draw();
                } else if (key == 'p' || key == 'P') {
                    handlePowerOff();
                    draw();
                } else if (key == 'r' || key == 'R') {
                    refreshDisks();
                    draw();
                }
            }
        }
    }
}
