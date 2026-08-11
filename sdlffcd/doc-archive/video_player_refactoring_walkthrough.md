# VideoPlayer Refactoring Walkthrough

## Summary of Changes
The monolithic `decode_video_file` function in `source/app.d` has been refactored into a reusable, non-blocking [`VideoPlayer`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/video_player.d) class.

Key achievements:
1. **Main Loop Safe**: The `VideoPlayer` does NOT call `sdlffcd_app_poll_events` or `sdlffcd_app_wait_events`. Main application events (such as keyboard callbacks and quit requests) are processed cleanly by the central event loop in [`source/app.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/app.d).
2. **Playback Controls**:
   - `pause()`, `resume()`, `togglePause()`
   - `rewind(seconds = 5.0)`
   - `fastForward(seconds = 5.0)`
   - `seekTo(targetPts)`
3. **C Library Seeking**: Added `sdlffcd_video_seek` to `sdlffcd_clib.h`, `sdlffcd_clib.c`, and [`source/sdlffcd_clib.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/sdlffcd_clib.d) using FFmpeg's `av_seek_frame` and `avcodec_flush_buffers`.
4. **Thread-Safe Ring Buffer Seeking**: Added seek target signaling and ring buffer flushing to [`FrameRingBuffer`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/frame_ring_buffer.d).

---

## File Modification Breakdown

### 1. `sdlffcd_clib` (C Library & D Bindings)
- **`sdlffcd_clib.h` / `sdlffcd_clib.c`**: Added `bool sdlffcd_video_seek(sdlffcd_VideoContext* vctx, double target_pts_seconds)`.
- **`source/sdlffcd_clib.d`**: Declared `sdlffcd_video_seek` D binding.

### 2. `source/frame_ring_buffer.d`
- Added `requestSeek(double targetPts)` to clear queued frames and signal `decodingWorker` to execute stream seek.
- Added `checkAndClearSeekRequest(out double targetPts)` for the background thread to safely process seek requests.

### 3. `source/video_player.d` (New File)
- Created [`VideoPlayer`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/video_player.d) class with:
  - `open(filename)` / `close()` lifecycle methods.
  - Non-blocking `update(app)` tick method that processes timestamps and renders ready frames.
  - State management for paused state with `MonoTime` clock adjustments.
  - `rewind()`, `fastForward()`, and `seekTo()` methods.

### 4. `source/app.d`
- Removed blocking `decode_video_file` function.
- Integrated `VideoPlayer` into main loop:
  - Key bindings: `Space`/`P` for Pause/Resume, `R`/`Left` for Rewind, `F`/`Right` for Fast Forward, `Q`/`ESC` for Quit.
  - Clean non-blocking main loop executing `sdlffcd_app_poll_events(app)` followed by `player.update(app)`.

---

## Verification Results
- **Build**: `dub build` completed cleanly, compiling C library target with Ninja and D application with LDC.
- **Playback Test**: Executed `timeout 2s ./sdlffcd samplevideo.mp4` successfully.
