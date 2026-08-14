# Implementation Plan: Video Trimming Controls, IN/OUT Markers, Loop Mode & FFmpeg Command Export

Implement new key controls, frame stepping, IN/OUT cut markers, looping playback, FFmpeg lossless cut command export, updated overlay HUD text, CLI options, and rename long app name to "sdlffcd video trimming tool".

---

## User Review Required

> [!IMPORTANT]
> Key updates to be aware of:
> 1. **Key mapping changes**:
>    - `Left` / `Right` arrows now handle 5s seek backward/forward (previously `R` and `F`).
>    - `F` is now dedicated to **Fullscreen Toggle**.
>    - `V` cycles timestamp/HUD position (previously `T`).
>    - `[` and `]` step 1 frame backward / forward (pauses playback if currently playing).
>    - `B` seeks to start frame (00:00:00.000); `E` seeks to end frame (`duration - 1/fps`).
>    - `I` / `O` set IN/OUT markers; `Shift + I` / `Shift + O` seek to IN/OUT markers.
>    - `L` toggles looping between IN and OUT markers.
>    - `Enter` prints lossless FFmpeg cut command to stdout.
>    - `Q` / `Esc` quits (and automatically prints FFmpeg cut command if markers were modified).
> 2. **CLI & Playback Completion Behavior**:
>    - Running `sdlffcd` with no arguments or `--help` / `-h` displays the full help message to stdout.
>    - Reaching the end of the video pauses at the end without exiting unless `--quit` is specified.
> 3. **Output File Naming for FFmpeg Command**:
>    - Generates output file name formatted as `<input_stem>_HHMMSS_mmm_HHMMSS_mmm_cut.<ext>` (e.g. `samplevideo_000005_000_000025_500_cut.mp4`).
> 4. **C Library & D Bindings Synchronization**:
>    - `sdlffcd_clib.h` and `source/sdlffcd_clib.d` maintain strict 1-to-1 sync, including key modifier detection and fullscreen window toggling.

---

## Proposed Changes

### 1. C Bridge Library (`sdlffcd_clib`)
Synchronized across `sdlffcd_clib/sdlffcd_clib.h`, `sdlffcd_clib/sdlffcd_clib.c`, and `source/sdlffcd_clib.d`.

#### [MODIFY] `sdlffcd_clib/sdlffcd_clib.h` & `source/sdlffcd_clib.d`
- Add `sdlffcd_KeyMod` enum: `SDLFFCD_KMOD_NONE`, `SDLFFCD_KMOD_SHIFT`, `SDLFFCD_KMOD_CTRL`, `SDLFFCD_KMOD_ALT`.
- Add keycodes to `sdlffcd_Key` enum: `SDLFFCD_KEY_RETURN = 13`, `SDLFFCD_KEY_LEFTBRACKET = '['`, `SDLFFCD_KEY_RIGHTBRACKET = ']'`, `SDLFFCD_KEY_B = 'b'`, `SDLFFCD_KEY_E = 'e'`, `SDLFFCD_KEY_I = 'i'`, `SDLFFCD_KEY_L = 'l'`, `SDLFFCD_KEY_O = 'o'`, `SDLFFCD_KEY_V = 'v'`.
- Update `sdlffcd_KeyCallback` to `typedef void (*sdlffcd_KeyCallback)(void* userdata, uint32_t key, uint16_t mod);`.
- Add fullscreen APIs: `bool sdlffcd_app_toggle_fullscreen(sdlffcd_AppContext* app);` and `bool sdlffcd_app_is_fullscreen(const sdlffcd_AppContext* app);`.

#### [MODIFY] `sdlffcd_clib/sdlffcd_clib.c`
- In `process_single_event`, extract `event->key.mod` and populate `uint16_t mod`.
- Implement `sdlffcd_app_toggle_fullscreen` and `sdlffcd_app_is_fullscreen` via `SDL_SetWindowFullscreen` / `SDL_GetWindowFlags`.

---

### 2. Models & Data Structures (`source/models.d`)

#### [MODIFY] `source/models.d`
- Update `formatTimestamp(double posSec, double totalSec, bool isLooping = false, bool isPaused = false)`:
  - Appends `[LOOP]` and `[PAUSED]` flags appropriately (e.g. `00:00:12.345 / 00:02:05.789 [LOOP] [PAUSED]`).
- Add `formatInOut(double timeIn, double timeOut)`:
  - Formats `IN: 00:00:05.000  OUT: 00:00:25.500`.
- Add `generateFfmpegCutCommand(string inputFilename, double timeIn, double timeOut, double fps)`:
  - Computes `cutDuration = (timeOut - timeIn) + singleFrameDisplayTime`.
  - Formats output filename with timestamps: `<input_stem>_%02d%02d%02d_%03d_%02d%02d%02d_%03d_cut.<ext>` (e.g., `samplevideo_000005_000_000025_500_cut.mp4`).
  - Generates command: `ffmpeg -ss <in_hms> -i "<input>" -t <dur_hms> -c:v copy -c:a copy "<output_filename>"`.
- Update `ViewFields` to include `string formattedInOutTime`.
- Update `EditFields` to track `bool markersModified`.
- Add unit tests for all timestamp formatting, in/out formatting, and ffmpeg command generation.

---

### 3. Video Player Core (`source/video_player.d`)

#### [MODIFY] `source/video_player.d`
- Add `stepFrame(int direction)`: pauses if playing, calculates `1.0 / fps` (or 1/30), seeks by one frame step.
- Add `getFps()` and `getEndFrameTime()`: `getEndFrameTime()` returns `max(0.0, duration - (fps > 0 ? 1.0 / fps : 0.0))`.
- Update `handlePaused`: when paused and a seek is in flight, pop the decoded slot, render the frame, update `currentPts`, and remain paused.

---

### 4. Player View & HUD Text Overlay (`source/player_view.d`)

#### [MODIFY] `source/player_view.d`
- Add `sdlffcd_Text* inOutText` alongside `timestampText`.
- Render `inOutText` stacked below `timestampText` with background rectangle matching the exact styling.
- Align positions correctly for `topLeft`, `topRight`, `bottomRight`, `bottomLeft`, and hide both on `invisible`.

---

### 5. Player Controller & Input Routing (`source/player_controller.d`)

#### [MODIFY] `source/player_controller.d`
- Initialize `editModel.timeIn = 0.0` and `editModel.timeOut = endFrameTime`.
- Handle key actions:
  - `Space`: `togglePause()`
  - `Left` / `Right`: seek -5s / +5s
  - `[` / `]`: `stepFrame(-1)` / `stepFrame(+1)`
  - `B`: seek to 0.0
  - `E`: seek to `getEndFrameTime()`
  - `I` without Shift: set `timeIn = currentPts`, mark `markersModified = true`
  - `O` without Shift: set `timeOut = currentPts`, mark `markersModified = true`
  - `Shift + I`: seek to `editModel.timeIn`
  - `Shift + O`: seek to `editModel.timeOut`
  - `L`: toggle `playerModel.isLooping`
  - `F`: toggle fullscreen mode
  - `V`: cycle HUD position
  - `Enter`: print FFmpeg cut command to stdout
  - `Q` / `Esc`: quit application; if `markersModified`, print FFmpeg cut command to stdout
- In `update(appContext)`:
  - If looping is enabled and `currentPts >= editModel.timeOut`, seek to `editModel.timeIn`.
  - Handle EOF: if `quitOnEnd`, return quit; if looping, seek to `editModel.timeIn`; otherwise pause at end.
  - Update `viewModel.formattedCurrentTotalTime` and `viewModel.formattedInOutTime`.

---

### 6. App Entrypoint, CLI & Documentation (`source/app.d`, `README.md`)

#### [MODIFY] `source/app.d`
- Parse command-line arguments:
  - If no args or `--help` / `-h`: print full help text and exit.
  - If `--quit`: enable `quitOnEnd`.
  - Set window title to `"sdlffcd video trimming tool"`.
- Pass updated key and modifier parameters from C callback to controller.

#### [MODIFY] `README.md`
- Update title and description to `"sdlffcd video trimming tool"`.
- Document new keybindings, looping, IN/OUT trimming, and CLI options.

---

## Verification Plan

### Automated Tests
- Run full test suite:
  ```bash
  dub test
  ```
- Validate all unit tests in `models.d`, `video_player.d`, `player_controller.d`, and `sdlffcd_clib.d`.

### Manual Verification
- Test CLI help with no arguments and `--help`:
  ```bash
  ./sdlffcd --help
  ./sdlffcd
  ```
- Test video playback with `samplevideo.mp4`:
  ```bash
  ./sdlffcd samplevideo.mp4
  ```
- Verify:
  1. `Space` pauses and resumes playback, overlay updates `[PAUSED]`.
  2. `[` and `]` step single frames backward and forward while paused.
  3. `I` sets IN point, `O` sets OUT point; HUD displays `IN: ... OUT: ...`.
  4. `Shift + I` and `Shift + O` seek to IN and OUT points.
  5. `L` toggles looping mode, overlay shows `[LOOP]`, playback loops between IN and OUT markers.
  6. `F` toggles fullscreen mode.
  7. `V` cycles HUD overlay through all 4 corners and hidden.
  8. `Enter` prints the ffmpeg cut command with formatted output name (e.g. `<stem>_HHMMSS_mmm_HHMMSS_mmm_cut.<ext>`) to stdout.
  9. `Q` / `Esc` quits and auto-prints the ffmpeg cut command if markers were changed.
  10. `--quit` option causes player to exit cleanly on video completion.
