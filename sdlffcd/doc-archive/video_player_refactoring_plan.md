# VideoPlayer Refactoring Plan

## Objectives
1. **Refactor `decode_video_file`**: Extract the monolithic decoding and rendering loop from [`source/app.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/app.d) into a dedicated, reusable [`VideoPlayer`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/video_player.d) class.
2. **Main Event Loop Safety**: Eliminate calls to `sdlffcd_app_poll_events` inside the player. The `VideoPlayer` provides a non-blocking `update()` method called directly from the application's main event loop.
3. **Playback Controls**:
   - **Pause / Resume**: Toggle playback state without losing timestamp sync.
   - **Rewind / Fast Forward**: Support relative seeking (e.g. ±5 seconds) and speed multipliers (1.0x, 2.0x, etc.).
4. **C Library Seeking Support**: Expose `sdlffcd_video_seek` in `sdlffcd_clib` to perform frame/stream seeking via FFmpeg.

---

## Key Architecture & Design

### 1. C Library Seek Function (`sdlffcd_clib`)
- Add `bool sdlffcd_video_seek(sdlffcd_VideoContext* vctx, double target_pts_seconds)` to `sdlffcd_clib.h`, `sdlffcd_clib.c`, and [`source/sdlffcd_clib.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/sdlffcd_clib.d).
- Implementation converts `target_pts_seconds` into stream timebase units, calls `av_seek_frame(..., AVSEEK_FLAG_BACKWARD)`, and flushes codec buffers with `avcodec_flush_buffers`.

### 2. `FrameRingBuffer` Flush & Seek Support
- Add `requestSeek(double targetPts)` and `checkAndClearSeekRequest(out double targetPts)` to [`FrameRingBuffer`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/frame_ring_buffer.d).
- When seeking, the ring buffer flushes stale queued slots and signals the `decodingWorker` thread to seek the FFmpeg context before decoding resumes.

### 3. `VideoPlayer` Class (`source/video_player.d`)
- **Initialization**: `open(filename)` initializes `sdlffcd_VideoContext`, metadata, ring buffer, and producer thread.
- **Main Loop Step**: `bool update(sdlffcd_AppContext* app)`:
  - Non-blocking frame pop from `FrameRingBuffer`.
  - Timing check relative to `MonoTime` clock.
  - Renders frame when presentation time is reached.
  - Returns frame status / stream state to main loop.
- **Control Methods**:
  - `void pause()`, `void resume()`, `void togglePause()`, `bool isPaused()`
  - `void rewind(double seconds = 5.0)`
  - `void fastForward(double seconds = 5.0)`
  - `void setSpeed(double speed)`

### 4. Main Event Loop (`source/app.d`)
- The main thread handles all SDL events (`sdlffcd_app_poll_events` / key callbacks).
- Key bindings:
  - `Space`: Pause / Resume toggle
  - `Left Arrow` / `R`: Rewind 5 seconds
  - `Right Arrow` / `F`: Fast Forward 5 seconds
  - `Q` / `Escape`: Quit application
- Inside the main `while(sdlffcd_app_is_running(app))` loop, `sdlffcd_app_poll_events(app)` is called once per tick, followed by `player.update(app)`.

---

## Verification Plan
1. Build C library and D executable using `dub build`.
2. Run `dub run -- samplevideo.mp4` to test video playback.
3. Verify key handling (Space bar pause/resume, Arrow keys for seek, Q/ESC for exit).
4. Verify non-blocking behavior of event loop and clean exit.
