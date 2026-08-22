import std.stdio;
import std.format;
import std.algorithm : min, max;
import std.array : appender;
import core.thread;
import core.time;
import core.sys.posix.signal;
import arsd.terminal;

static shared bool g_running = true;

extern(C) void handleSignal(int sig) nothrow @nogc @system {
    g_running = false;
}

struct RGB {
    ubyte r, g, b;

    RGB darken(float factor = 0.4f) const {
        return RGB(
            cast(ubyte)(r * factor),
            cast(ubyte)(g * factor),
            cast(ubyte)(b * factor)
        );
    }
}

struct Cell {
    dchar ch = ' ';
    RGB fg = RGB(220, 220, 220);
    RGB bg = RGB(25, 30, 40);
}

class TerminalBuffer {
    int width;
    int height;
    Cell[] current;
    Cell[] previous;

    this(int w, int h) {
        width = max(1, w);
        height = max(1, h);
        current = new Cell[](width * height);
        previous = new Cell[](width * height);

        // Initialize with default fill
        clear(RGB(25, 30, 40));
        // Force initial diff by setting previous buffer characters to null
        foreach (ref cell; previous) {
            cell.ch = '\0';
        }
    }

    void clear(RGB bg) {
        foreach (y; 0 .. height) {
            foreach (x; 0 .. width) {
                current[y * width + x] = Cell('·', RGB(60, 70, 90), bg);
            }
        }
    }

    void drawText(int x, int y, string text, RGB fg, RGB bg) {
        if (y < 0 || y >= height) return;
        int cx = x;
        foreach (dchar ch; text) {
            if (cx >= 0 && cx < width) {
                current[y * width + cx] = Cell(ch, fg, bg);
            }
            cx++;
        }
    }

    void applyShadow(int x, int y, int w, int h, int offX = 2, int offY = 1) {
        foreach (sy; (y + offY) .. (y + h + offY)) {
            foreach (sx; (x + offX) .. (x + w + offX)) {
                if (sx >= 0 && sx < width && sy >= 0 && sy < height) {
                    // Darken only cells outside the actual window boundary
                    if (!(sx >= x && sx < x + w && sy >= y && sy < y + h)) {
                        int idx = sy * width + sx;
                        current[idx].fg = current[idx].fg.darken(0.35f);
                        current[idx].bg = current[idx].bg.darken(0.35f);
                    }
                }
            }
        }
    }

    void drawModal(int x, int y, int w, int h, string title) {
        // Step 1: Darken whatever cells are currently beneath the shadow area
        applyShadow(x, y, w, h, 2, 1);

        // Step 2: Draw the window over the buffer
        RGB winBg = RGB(235, 238, 245);
        RGB winFg = RGB(20, 25, 35);
        RGB borderFg = RGB(120, 130, 150);

        foreach (row; y .. (y + h)) {
            foreach (col; x .. (x + w)) {
                if (col >= 0 && col < width && row >= 0 && row < height) {
                    dchar ch = ' ';
                    if (row == y || row == y + h - 1) ch = '─';
                    else if (col == x || col == x + w - 1) ch = '│';
                    current[row * width + col] = Cell(ch, borderFg, winBg);
                }
            }
        }

        // Window Corners
        if (x >= 0 && x < width && y >= 0 && y < height) current[y * width + x].ch = '┌';
        if (x + w - 1 >= 0 && x + w - 1 < width && y >= 0 && y < height) current[y * width + (x + w - 1)].ch = '┐';
        if (x >= 0 && x < width && y + h - 1 >= 0 && y + h - 1 < height) current[(y + h - 1) * width + x].ch = '└';
        if (x + w - 1 >= 0 && x + w - 1 < width && y + h - 1 >= 0 && y + h - 1 < height) current[(y + h - 1) * width + (x + w - 1)].ch = '┘';

        // Content
        if (h >= 4) {
            drawText(x + 2, y + 1, " " ~ title ~ " ", winFg, winBg);
            drawText(x + 2, y + 3, "Real-time shadow compositing", winFg, winBg);
        } else if (h >= 2) {
            drawText(x + 2, y + 1, " " ~ title ~ " ", winFg, winBg);
        }
    }

    void flush(Terminal* terminal) {
        auto app = appender!string();

        int lastX = -2;
        int lastY = -2;
        RGB lastFg = RGB(0, 0, 0);
        RGB lastBg = RGB(0, 0, 0);
        bool colorSet = false;

        foreach (y; 0 .. height) {
            foreach (x; 0 .. width) {
                int idx = y * width + x;
                auto cur = current[idx];
                auto prev = previous[idx];

                // Emit ANSI updates only for modified cells
                if (cur.ch != prev.ch || cur.fg != prev.fg || cur.bg != prev.bg) {
                    // Reposition cursor if not adjacent to last character
                    if (x != lastX + 1 || y != lastY) {
                        app.formattedWrite("\033[%d;%dH", y + 1, x + 1);
                    }
                    lastX = x;
                    lastY = y;

                    // Update colors if changed
                    if (!colorSet || cur.fg != lastFg || cur.bg != lastBg) {
                        app.formattedWrite("\033[38;2;%d;%d;%dm\033[48;2;%d;%d;%dm",
                            cur.fg.r, cur.fg.g, cur.fg.b,
                            cur.bg.r, cur.bg.g, cur.bg.b
                        );
                        lastFg = cur.fg;
                        lastBg = cur.bg;
                        colorSet = true;
                    }

                    app.put(cur.ch);
                    previous[idx] = cur;
                }
            }
        }

        if (app.data.length > 0) {
            terminal.writeStringRaw(app.data);
            terminal.flush();
        }
    }
}

void main() {
    // Setup signal handlers for graceful exit
    signal(SIGINT, &handleSignal);
    signal(SIGTERM, &handleSignal);
    signal(SIGHUP, &handleSignal);
    signal(SIGQUIT, &handleSignal);

    // Initialize arsd.terminal with cellular mode
    auto terminal = Terminal(ConsoleOutputType.cellular);
    terminal.hideCursor();
    terminal.clear();

    // Ensure clean state on exit
    scope(exit) {
        terminal.reset();
        terminal.showCursor();
        terminal.flush();
    }

    int termW = terminal.width > 0 ? terminal.width : 80;
    int termH = terminal.height > 0 ? terminal.height : 24;
    auto buf = new TerminalBuffer(termW, termH);

    int modalW = min(36, max(16, termW - 8));
    int modalH = min(6, max(4, termH - 6));
    int totalFrames = 36;

    foreach (frame; 0 .. totalFrames) {
        if (!g_running) break;

        // Handle possible terminal resize
        if (terminal.width > 0 && terminal.height > 0 &&
            (terminal.width != buf.width || terminal.height != buf.height)) {
            termW = terminal.width;
            termH = terminal.height;
            terminal.clear();
            buf = new TerminalBuffer(termW, termH);
            modalW = min(36, max(16, termW - 8));
            modalH = min(6, max(4, termH - 6));
        }

        buf.clear(RGB(25, 30, 40));

        // Header & background content matching terminal size
        buf.drawText(2, 1, "D-LANG BUFFER COMPOSITOR DEMO (arsd.terminal)", RGB(255, 215, 0), RGB(25, 30, 40));
        string statusText = format("Terminal: %dx%d | 24-bit TrueColor Compositing", buf.width, buf.height);
        buf.drawText(2, 2, statusText, RGB(100, 180, 240), RGB(25, 30, 40));

        string samplePattern = "The quick brown fox jumps over the lazy dog [0123456789] · ";
        foreach (line; 4 .. max(4, buf.height - 2)) {
            string lineText;
            while (lineText.length < buf.width) {
                lineText ~= samplePattern;
            }
            buf.drawText(2, line, lineText[0 .. min($, buf.width - 4)], RGB(130, 160, 190), RGB(25, 30, 40));
        }

        // Footer status line
        if (buf.height > 3) {
            string footer = format("Frame %2d/%2d | Compositing Active | Press Ctrl+C to exit", frame + 1, totalFrames);
            buf.drawText(2, buf.height - 2, footer, RGB(140, 190, 140), RGB(25, 30, 40));
        }

        // Animate floating modal with drop shadow across the available area
        int maxX = max(2, buf.width - modalW - 4);
        int maxY = max(2, buf.height - modalH - 3);
        float progress = totalFrames > 1 ? cast(float)frame / (totalFrames - 1) : 0.0f;
        int modalX = 2 + cast(int)((maxX - 2) * progress);
        int modalY = 2 + cast(int)((maxY - 2) * progress);

        buf.drawModal(modalX, modalY, modalW, modalH, "DUB / arsd.terminal");

        buf.flush(&terminal);
        Thread.sleep(60.msecs);
    }
}