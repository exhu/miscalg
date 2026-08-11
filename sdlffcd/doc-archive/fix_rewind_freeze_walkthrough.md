# Fix Video Playback Freeze on Rewind - Walkthrough

## Summary of Changes
Fixed video playback freeze when the rewind function (`VideoPlayer.rewind()`) or rewind keyboard shortcuts (`R` / `Left Arrow`) are triggered.

## Key Changes

### 1. `FrameRingBuffer` Seek Cancellation (`source/frame_ring_buffer.d`)
- Updated `FrameRingBuffer.push()` to check `seekRequested` alongside `stopRequested` when waking up from `notFull.wait()`.
- If `seekRequested` is set, `push()` discards the stale pre-seek frame and returns `false` without pushing it into the buffer.
- Added comprehensive unit tests in `FrameRingBuffer` covering push, pop, seek request signaling, and push cancellation.

### 2. `VideoPlayer` Thread Loop & Clock Sync (`source/video_player.d`)
- Modified `decodingWorker` so that push rejections due to `seekRequested` do not cause the thread to break out of its loop. The worker continues looping to process `checkAndClearSeekRequest` and execute `sdlffcd_video_seek`.
- Updated `VideoPlayer.seekTo()` to reset `frameCount` to `cast(long)(targetPts * mediaInfo.fps)` so fallback frame calculations remain synchronized with the seek target.
- Adjusted `VideoPlayer.update()` PTS fallback check from `framePts <= 0.0` to `framePts < 0.0`, allowing valid presentation timestamps at `0.0` (such as frame 0 or start-of-file keyframes) to process normally without being overwritten.

### 3. `sdlffcd_clib` Missing PTS Fallback (`sdlffcd_clib/sdlffcd_clib.c`)
- Updated `sdlffcd_video_decode_frame` to check `vctx->frame->best_effort_timestamp` when `pts == AV_NOPTS_VALUE`.
- Set default missing PTS marker to `-1.0` (instead of `0.0`), allowing D callers to distinguish missing timestamps from timestamp 0.0.

## Verification
- Built static C library and D executable (`dub build`).
- Executed unit tests (`dub test`), all tests passed cleanly.
- Tested video player execution with `samplevideo.mp4`.
