# Walkthrough - D to Modern Free Pascal Rewrite of `diskpoff-tui`

We have rewritten the D console application [`diskpoff-tui`](file:///home/yur/agy-projects/miscalg/fpc/pdiskpofftui/original-d) into modern, idiomatic Free Pascal (FPC 3.2.2+).

---

## 1. Project Structure

```
/home/yur/agy-projects/miscalg/fpc/pdiskpofftui/
├── Makefile                     # Build targets (all, test, debug, lazbuild, clean)
├── pdiskpofftui.lpr             # Main application entry point
├── pdiskpofftui.lpi             # Lazarus project file (Release & Debug modes)
├── src/
│   ├── uboxdrawing.pas          # Box drawing glyphs and border styles
│   ├── ucommon.pas              # UTF-8 string measurement, truncation, and utilities
│   ├── udevice.pas              # Device hierarchy, lsblk parser, udisksctl actions
│   ├── uterminal.pas            # Pure ANSI/VT100 & Linux termios raw mode engine
│   └── uui.pas                  # TTuiApp layout, scrolling, rendering, and event loop
└── tests/
    ├── test_runner.lpr          # Automated test suite
    └── test_runner.lpi          # Lazarus project file for test suite
```

---

## 2. Key Components & Implementation Details

### A. Terminal & Event Engine ([`src/uterminal.pas`](file:///home/yur/agy-projects/miscalg/fpc/pdiskpofftui/src/uterminal.pas))
- Zero C-library dependencies (no ncurses/libtinfo required).
- Configures non-canonical raw mode with `termio.TCSetAttr` and restores original terminal attributes cleanly on exit or error.
- Utilizes the terminal's alternate screen buffer (`\e[?1049h` / `\e[?1049l`) and hides the cursor during execution.
- Live dimension detection via `TIOCGWINSZ`.
- Non-blocking event decoding (`PollKeyEvent` via `fpSelect`) supporting character keys, Arrow keys, `PgUp`/`PgDn`, `Home`/`End`, `Enter`, `Escape`, and `Ctrl+C`/`Ctrl+D`.

### B. Device Model & Subprocess Execution ([`src/udevice.pas`](file:///home/yur/agy-projects/miscalg/fpc/pdiskpofftui/src/udevice.pas))
- Parses `lsblk -J` block device hierarchies using standard `fcl-json` (`fpjson` + `jsonparser`).
- Asynchronous subprocess execution (`TProcess`) with live busy spinner updates during long operations.
- Full support for nested LUKS encrypted volumes and LVM hierarchies:
  - **Depth-first unmounting**: unmounts child filesystems before locking parent crypto containers.
  - **Mount candidate resolution**: collects unmounted mountable partitions while automatically excluding swap partitions and locked LUKS volumes.
  - Device actions: `FetchDisks`, `MountSinglePartition`, `MountDiskPartitions`, `UnmountAndLockPartition`, `UnmountAndLockDisk`, and `PowerOffDiskDevice`.

### C. TUI Application & Table Layout ([`src/uui.pas`](file:///home/yur/agy-projects/miscalg/fpc/pdiskpofftui/src/uui.pas))
- Proportional dynamic column scaling for Device, Model/Name, Serial, and Mount/Crypt columns.
- Unicode box drawing borders (`DoubleStyle` and `DoubleHorizSingleVertStyle`).
- Selection highlight and status bar with color-coded alerts (green on success, red on error, animated spinner during pending tasks).

---

## 3. Verification & Test Results

### A. Automated Test Suite
Ran `make test` executing all test cases in [`tests/test_runner.lpr`](file:///home/yur/agy-projects/miscalg/fpc/pdiskpofftui/tests/test_runner.lpr):
- `TestCommonAndUtf8`: UTF-8 character length, padding, truncation with ellipsis, string array helpers.
- `TestBoxDrawingStyles`: Box drawing characters and styles.
- `TestDeviceParsingSampleJson`: Standard partitions, LUKS crypto volumes, mount point parsing, unmount/lock path ordering.
- `TestComplexLvmOverLuksAndSwap`: Nested LVM over LUKS with root, home, and swap partitions.
- `TestSwapExclusion`: Swap exclusion on single and multi-partition drives, empty and malformed JSON resilience.

```
=== Running diskpoff-tui Free Pascal Test Suite ===
Running TestCommonAndUtf8...
Running TestBoxDrawingStyles...
Running TestDeviceParsingSampleJson...
Running TestComplexLvmOverLuksAndSwap...
Running TestSwapExclusion...
==================================================
Results: 108 passed, 0 failed.
```

### B. Dual Build System Verification
1. **Command Line `make`**:
   - `make pdiskpofftui` compiles optimized binary `bin/pdiskpofftui`.
   - `make test` compiles and runs test suite `bin/test_runner`.
2. **Lazarus IDE `lazbuild`**:
   - `lazbuild pdiskpofftui.lpi` built successfully with zero errors.
   - `lazbuild tests/test_runner.lpi` built successfully with zero errors.

### C. Interactive & TTY Verification
- Verified non-interactive execution (`./bin/pdiskpofftui < /dev/null`) correctly reports:
  `diskpoff-tui must be run from an interactive terminal.` and exits with code 1.
- Verified interactive execution inside terminal: successfully queried system block devices, rendered full UI table with live NVMe/SATA device listing, responded to key commands, and cleanly restored terminal on exit.
