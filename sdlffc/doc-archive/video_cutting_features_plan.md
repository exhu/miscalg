# Video Cutting & Marker Feature Implementation Plan (Updated)

This document outlines the design and implementation strategy for adding video cutting controls, marker handling, looping playback between markers, lossless FFmpeg command export, enhanced 2-line timestamp overlay with positioning cycle, and CLI help to `sdlffc`.

## Goal Description
Transform `sdlffc` into an interactive video cutting utility by providing:
- Key bindings to seek to video start/end (`B`/`E`), set cut in/out markers (`I`/`O`), and jump to markers (`Shift+I`/`Shift+O`).
- Initializing IN marker to the first frame (`0.0s`) and OUT marker to the final visible frame's timestamp (`duration - frame_duration`).
- Looping playback (`L`) bounded between IN and OUT markers (inclusive of the OUT frame).
- Lossless FFmpeg export command (`Enter` or automatically on `Q`/`Esc` if markers were modified) printed to `stdout` using `-c:v copy -c:a copy -map 0 -t <duration>`.
- Enhanced 2-line timestamp overlay (Line 1: current/total time, Line 2: yellow IN/OUT markers) over an 80% opacity black background box.
- Overlay state cycle on key `V` (Top-Left -> Bottom-Right -> Hidden -> Top-Left).
- Command-line help (`--help` / `-h`) listing usage instructions and all keyboard shortcuts.

---

## User Review Required

> [!IMPORTANT]
> **Key V Overlay Cycle**: Key `V` controls the timestamp overlay, cycling between:
> 1. Top-Left corner (default)
> 2. Bottom-Right corner
> 3. Hidden
> Key `O` is dedicated strictly to setting the OUT marker (`Shift+O` seeks to OUT marker).

> [!IMPORTANT]
> **Auto-Print FFmpeg Command on Quit**: If the user has modified the IN or OUT markers during the session, quitting via `Q` or `Esc` will automatically print the lossless `ffmpeg` cut command to `stdout` before exiting.

---

## Proposed Changes

```mermaid
flowchart TD
    A[sdlffc CLI / --help] --> B[sdlffclib_open_video]
    B --> C["Set in_point = 0.0s, out_point = last_frame_time"]
    C --> D[sdlffclib_main_loop]
    D --> E[Keyboard Event Handler]
    E -->|B / E| F[Seek Start / End]
    E -->|I / O| G[Set IN / OUT Marker & Set markers_modified = true]
    E -->|Shift+I / Shift+O| H[Seek IN / OUT Marker]
    E -->|L| I[Toggle Looping [IN, OUT]]
    E -->|V| J[Cycle Overlay: Top-Left -> Bottom-Right -> Hidden]
    E -->|Enter| K[Print Lossless FFmpeg Command to stdout]
    E -->|Q / ESC| L{markers_modified?}
    L -->|Yes| M[Print Lossless FFmpeg Command to stdout] --> N[Quit]
    L -->|No| N[Quit]
    D --> O[render_timestamp_overlay]
    O --> P[Line 1: White Current/Total]
    O --> Q[Line 2: Yellow IN/OUT Timestamps]
    O --> R[80% Opacity Black Background Box at Top-Left / Bottom-Right]
```

### 1. Main Entry & CLI Help (`sdlffc.c`)

#### [MODIFY] [sdlffc.c](file:///home/yur/agy-projects/miscalg/sdlffc/sdlffc.c)
- Check for `-h` or `--help` command-line arguments.
- Print formatted help listing usage and all keyboard shortcuts:
  - `Space`: Pause / Resume playback
  - `Left / Right`: Seek backward / forward 5s
  - `[ / ]`: Step 1 frame backward / forward
  - `B`: Seek to video start frame
  - `E`: Seek to video end frame
  - `I`: Set IN-marker to current frame time
  - `O`: Set OUT-marker to current frame time
  - `Shift + I`: Seek to IN-marker position
  - `Shift + O`: Seek to OUT-marker position
  - `L`: Toggle looping between IN and OUT markers
  - `V`: Cycle overlay position (Top-Left -> Bottom-Right -> Hidden)
  - `Enter`: Print lossless FFmpeg cut command to stdout
  - `Q / Esc`: Quit application (prints FFmpeg command automatically if markers were modified)
- Exit with code `0` when `--help` or `-h` is requested.

---

### 2. Context Structure & Declarations (`sdlffclib_private.h`)

#### [MODIFY] [sdlffclib_private.h](file:///home/yur/agy-projects/miscalg/sdlffc/sdlffclib_private.h)
- Define overlay position mode enum:
  ```c
  typedef enum {
    OVERLAY_TOP_LEFT = 0,
    OVERLAY_BOTTOM_RIGHT = 1,
    OVERLAY_HIDDEN = 2
  } OverlayMode;
  ```
- Add fields to `_SdlffContext`:
  - `char file_path[1024]`
  - `bool looping`
  - `bool markers_modified`
  - `OverlayMode overlay_mode`

---

### 3. Core Logic, Keyboard Shortcuts & Looping (`sdlffclib.c`)

#### [MODIFY] [sdlffclib.c](file:///home/yur/agy-projects/miscalg/sdlffc/sdlffclib.c)
- **`sdlffclib_open_video`**:
  - Save input `file_path` to `context->file_path`.
  - Calculate frame duration $dt = \text{min\_seek\_increment}$.
  - Initialize `context->in_point = 0.0`.
  - Initialize `context->out_point = (duration_sec > dt) ? (duration_sec - dt) : 0.0` (final displayed frame's timestamp).
  - Initialize `context->looping = false`.
  - Initialize `context->markers_modified = false`.
  - Initialize `context->overlay_mode = OVERLAY_TOP_LEFT`.

- **Helper Function `print_ffmpeg_command`**:
  - Encapsulate FFmpeg command string formatting and printing to `stdout`.
  - Calculate cut duration: `cut_duration = (out_point - in_point) + min_seek_increment`.
  - Output filename: `<path_without_ext>_<IN_HH_MM_SS>_<OUT_HH_MM_SS>.<ext>`.
  - Print command to `stdout`:
    `ffmpeg -ss <in_str> -i "<file_path>" -t <dur_str> -c:v copy -c:a copy -map 0 "<output_file>"`

- **`handle_key_should_quit`**:
  - `Key Q / Esc`:
    - If `context->markers_modified` is true, call `print_ffmpeg_command(context)`.
    - Return `true` to quit.
  - `Key B`: Seek to 0.0s (cancels looping).
  - `Key E`: Seek to `out_point` / end frame (cancels looping).
  - `Key I` / `Shift+I`:
    - Shift pressed: seek to `in_point` (cancels looping).
    - Shift not pressed: set `in_point = current_pos`, `markers_modified = true`, redraw overlay (cancels looping).
  - `Key O` / `Shift+O`:
    - Shift pressed: seek to `out_point` (cancels looping).
    - Shift not pressed: set `out_point = current_pos`, `markers_modified = true`, redraw overlay (cancels looping).
  - `Key L`:
    - Toggle `context->looping`.
    - If enabled: if paused, unpause; seek to `in_point`.
  - `Key V`:
    - Cycle `context->overlay_mode = (context->overlay_mode + 1) % 3`.
    - Redraw current frame.
  - `Key Space`: Pause/resume playback (does **not** cancel looping).
  - `Key Enter`:
    - Call `print_ffmpeg_command(context)`.
  - Other seek/step keys (`Left`, `Right`, `[`, `]`): perform seek/step and cancel looping.

- **`sdlffclib_main_loop`**:
  - In each iteration, if `context->looping` is true and current playback position `elapsed > (context->out_point + min_seek_increment)` or `stream_ended`:
    - Reset `stream_ended = false`.
    - Seek back to `context->in_point`.

---

### 4. Timestamp Overlay (`video_render.c`)

#### [MODIFY] [video_render.c](file:///home/yur/agy-projects/miscalg/sdlffc/video_render.c)
- Check `context->overlay_mode`: if `OVERLAY_HIDDEN`, return immediately.
- Calculate bounding box width (`bg_w`) and height (`bg_h`) for 2 lines.
- Determine coordinates based on `context->overlay_mode`:
  - `OVERLAY_TOP_LEFT`: `start_x = 12.0f`, `start_y = 12.0f`.
  - `OVERLAY_BOTTOM_RIGHT`: `start_x = win_w - bg_w - 18.0f`, `start_y = win_h - bg_h - 18.0f`.
- Draw background box: black with 80% opacity (`0, 0, 0, 204`).
- Draw Line 1 (White `255, 255, 255`): `HH:MM:SS / HH:MM:SS` (` [PAUSED]`, ` [LOOP]`).
- Draw Line 2 (Yellow `255, 255, 0`): `IN: HH:MM:SS  OUT: HH:MM:SS`.

---

## Verification Plan

### Automated Tests
1. Run `./build.sh` to compile the codebase.
2. Run `meson test -C _build` to ensure all existing tests pass without regressions.

### Manual & Feature Verification
1. `./_build/sdlffc --help` -> verify CLI help text & shortcuts listing.
2. Verify marker defaults, `B`, `E`, `I`, `O`, `Shift+I`, `Shift+O`, `L`, `V` state transitions.
3. Test setting markers with `I` and `O`, then quitting with `Q`/`Esc` -> verify FFmpeg command is printed automatically to `stdout`.
