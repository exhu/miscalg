# Walkthrough: Video Trimming Controls, IN/OUT Markers, Loop Mode & FFmpeg Command Export

Successfully implemented new keybindings, frame-accurate stepping, IN/OUT cut markers, looping playback between markers, lossless FFmpeg cut command generation with timestamped output file naming, updated HUD text overlays, CLI flags (`--help`, `--quit`), and updated the application identity to "sdlffcd video trimming tool".

---

## Key Changes Made

### 1. C Bridge Library (`sdlffcd_clib`) & D Synchronized Bindings
- **`sdlffcd_clib/sdlffcd_clib.h` & `source/sdlffcd_clib.d`**:
  - Added keycode constants: `SDLFFCD_KEY_RETURN`, `SDLFFCD_KEY_LEFTBRACKET`, `SDLFFCD_KEY_RIGHTBRACKET`, `SDLFFCD_KEY_B`, `SDLFFCD_KEY_E`, `SDLFFCD_KEY_F`, `SDLFFCD_KEY_I`, `SDLFFCD_KEY_L`, `SDLFFCD_KEY_O`, `SDLFFCD_KEY_P`, `SDLFFCD_KEY_Q`, `SDLFFCD_KEY_R`, `SDLFFCD_KEY_T`, `SDLFFCD_KEY_V`.
  - Added `sdlffcd_KeyMod` enum (`SDLFFCD_KMOD_NONE`, `SDLFFCD_KMOD_SHIFT`, `SDLFFCD_KMOD_CTRL`, `SDLFFCD_KMOD_ALT`).
  - Updated key callback signature to `void function(void* userdata, uint key, ushort mod)`.
  - Added fullscreen API declarations: `sdlffcd_app_toggle_fullscreen` and `sdlffcd_app_is_fullscreen`.
- **`sdlffcd_clib/sdlffcd_clib.c`**:
  - Implemented keyboard modifier detection and forwarding in `process_single_event`.
  - Implemented `sdlffcd_app_toggle_fullscreen` and `sdlffcd_app_is_fullscreen` via `SDL_SetWindowFullscreen` and `SDL_GetWindowFlags`.
  - Implemented **frame-accurate seeking** in `sdlffcd_video_seek`: seeks backward to the preceding keyframe and decodes forward until reaching the target presentation timestamp (`pts >= target_pts - 0.5 * frame_dur`), caching the target frame for the next decode call.

### 2. Models & Data Structures (`source/models.d`)
- **HUD Formatting**:
  - Updated `formatTimestamp` to append `[LOOP]` and `[PAUSED]` indicators.
  - Added `formatInOut` to format `IN: HH:MM:SS.mmm  OUT: HH:MM:SS.mmm`.
- **FFmpeg Command Generation**:
  - Implemented `generateFfmpegCutCommand`:
    - Accounts for inclusive end frame display time (`duration = (timeOut - timeIn) + singleFrameDisplayTime`).
    - Formats output filename with timestamps: `<input_stem>_HHMMSS_mmm_HHMMSS_mmm_cut.<ext>`.
    - Generates command: `ffmpeg -ss <in_hms> -i "<input>" -t <dur_hms> -c:v copy -c:a copy "<output_filename>"`.
- **`EditFields` & `ViewFields`**:
  - Added `markersModified` to `EditFields` to track user edits.
  - Added `formattedInOutTime` to `ViewFields`.

### 3. Video Player Core (`source/video_player.d`)
- Added `stepFrame(int direction)` to pause if active and seek single frames backward or forward by `1.0 / fps`.
- Added `getFps()` and `getEndFrameTime()` helper methods.
- Added `pausedSeekPending` flag so that when the player is paused, event wakeups (such as non-seek keypresses or window events) do not consume/render buffered frames or advance playback.
- Updated `handlePaused` to consume and render the frame when a seek/step is actively initiated while paused.

### 4. Player View & HUD Overlay (`source/player_view.d`)
- Added `inOutText` alongside `timestampText`.
- Formatted and positioned `inOutText` stacked below `timestampText` with background box for all 4 corner positions (`topLeft`, `topRight`, `bottomRight`, `bottomLeft`) and hidden on `invisible`.

### 5. Player Controller & Input Routing (`source/player_controller.d`)
- Implemented full key map:
  - `Space`: Pause / Resume
  - `Left` / `Right`: Seek backward / forward 5s
  - `[` / `]`: Step 1 frame backward / forward (pauses playback)
  - `B`: Seek to video start frame (00:00:00.000)
  - `E`: Seek to video end frame
  - `I`: Set IN-marker to current frame
  - `O`: Set OUT-marker to current frame
  - `Shift + I`: Seek to IN-marker position (pauses playback if playing)
  - `Shift + O`: Seek to OUT-marker position (pauses playback if playing)
  - `L`: Toggle looping between IN and OUT markers
  - `F`: Toggle fullscreen window mode
  - `V`: Cycle HUD overlay position (Top-Left -> Top-Right -> Bottom-Right -> Bottom-Left -> Hidden)
  - `Enter`: Print lossless FFmpeg cut command to stdout
  - `Q` / `Esc`: Quit application (auto-prints FFmpeg command if markers modified)
- Handled loop playback boundary check (`currentPts >= timeOut` loops to `timeIn`).
- Handled end of stream (pauses at end unless `--quit` is specified or looping is active).

### 6. App Entrypoint, CLI & Documentation (`source/app.d`, `source/app_context.d`, `README.md`)
- Added CLI parsing in `source/app.d`:
  - Displays full help text on no arguments or `--help` / `-h`.
  - Supports `--quit` flag to exit on stream EOF.
- Renamed application to `"sdlffcd video trimming tool"` in window title, help text, and `README.md`.

---

## Verification Results

### Automated Tests
Ran `dub test`:
```text
6 modules passed unittests
```
All unit tests in `models.d`, `video_player.d`, `player_controller.d`, and `sdlffcd_clib.d` passed successfully.

### CLI Tests
Ran `./sdlffcd` and `./sdlffcd --help`:
```text
sdlffcd video trimming tool

Usage: sdlffcd [options] <video_file>

Options:
  --help, -h    Show this help message
  --quit        Quit application when reaching the end of video

Controls:
  Space         Pause / Resume video playback
  Left / Right  Seek backward / forward by 5 seconds
  [ / ]         Step 1 frame backward / forward (pauses if playing)
  B             Seek to video start frame (00:00:00, ignores IN-marker)
  E             Seek to video end frame (ignores OUT-marker)
  I             Set IN-marker (start of cut) to current frame time
  O             Set OUT-marker (last frame of cut) to current frame time
  Shift + I     Seek to IN-marker position (pauses if playing)
  Shift + O     Seek to OUT-marker position (pauses if playing)
  L             Toggle looping between IN and OUT markers
  F             Toggle fullscreen window mode
  V             Cycle current time overlay position (Top-Left -> Top-Right -> Bottom-Right -> Bottom-Left -> Hidden)
  Enter         Print lossless FFmpeg cut command to stdout
  Q / Esc       Quit application (auto-prints FFmpeg command if markers modified)
```
