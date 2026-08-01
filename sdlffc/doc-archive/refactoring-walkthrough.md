# Refactoring Walkthrough — `sdlffc`

The refactoring of the SDL3 + FFmpeg C99 video player context and pipeline has been successfully implemented and verified.

## Changes Made

### 1. Frame-Decoding Ring Buffer & PTS Timing
- Created [`frame_queue.h`](file:///home/yur/agy-projects/miscalg/sdlffc/frame_queue.h) and [`frame_queue.c`](file:///home/yur/agy-projects/miscalg/sdlffc/frame_queue.c):
  - Fixed-size 8-frame thread-safe ring buffer (`FrameQueue`) with mutex and condition variables.
  - Video thread decodes up to 8 frames ahead into the queue via `frame_queue_push()`.
  - Main thread pops frames matching real-time wall-clock PTS via `frame_queue_try_pop()`.
  - Responsive shutdown via `quit_requested` atomic flag and `frame_queue_flush()`.

### 2. Concurrency & Mailbox Bug Fixes
- [`mailbox.c`](file:///home/yur/agy-projects/miscalg/sdlffc/mailbox.c):
  - Fixed spurious wakeup handling in `mailbox_receive_and_lock()` by checking `mb->is_set` inside a loop when `SDL_WaitConditionTimeout` returns.
- [`sdlffclib.c`](file:///home/yur/agy-projects/miscalg/sdlffc/sdlffclib.c):
  - Fixed `sizeof` bug in `mailbox_init()` for `video_thread_mailbox` (was using `main_thread_mailbox_data`).

### 3. Resource Management & Leaks
- [`sdlffclib.c`](file:///home/yur/agy-projects/miscalg/sdlffc/sdlffclib.c):
  - Fixed memory leaks in `sdlffclib_free_video_file_ctx()` by checking and freeing `pkt`, `frame`, `audio_context`, and `video_context` independently without wrapping under `if (ctx->ic)`.
  - Fixed stale context state by clearing `global_context` with `memset` on `sdlffclib_init()`.

### 4. Warning Cleanups & Formatting
- Updated `stream->duration` print specifier to use portable `%" PRId64` with `<inttypes.h>`.
- Removed dead `SDL_RemoveTimer()` call and unused `timer_id` field.
- Added explicit type casts and diagnostic pragmas for FFmpeg pixel format switch statement.
- Added [`frame_queue.c`](file:///home/yur/agy-projects/miscalg/sdlffc/frame_queue.c) to [`meson.build`](file:///home/yur/agy-projects/miscalg/sdlffc/meson.build).

---

## Verification Results

### Build Verification
- Command: `./build.sh`
- Result: Build succeeded with **0 warnings** on all project source files under `warning_level=everything`.

### Execution Verification
- Command: `./run.sh`
- Result: Successfully loaded and decoded [`resenije.mp4`](file:///home/yur/agy-projects/miscalg/sdlffc/resenije.mp4) (H.264 464x848). Video plays with PTS wall-clock timing and exits cleanly.
