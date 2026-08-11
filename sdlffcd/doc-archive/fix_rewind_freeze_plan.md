# Fix Video Playback Freeze on Rewind

## Problem Analysis
When the rewind function (`VideoPlayer.rewind()`) or key shortcut (Left Arrow / 'R') is used during video playback, video playback freezes.

### Root Causes
1. **Stale Pre-Seek Frame Ingestion**: When `FrameRingBuffer.requestSeek()` is invoked while `decodingWorker` is waiting inside `FrameRingBuffer.push()`, the condition variable wakes the thread up. `push()` did not check `seekRequested`, causing it to write the stale pre-seek frame into slot 0.
2. **Worker Thread Termination Vulnerability**: In `VideoPlayer.decodingWorker`, `if (!pushed)` caused the thread loop to `break` permanently whenever `push()` returned `false`. If `push()` rejected a push on seek, the worker thread terminated permanently, preventing any subsequent frames from being decoded.
3. **Invalid PTS Fallback Bug**: `VideoPlayer.update()` checked `if (framePts <= 0.0)` to apply fallback timestamp calculation. PTS = 0.0 is a valid presentation timestamp for the start of video streams (frame 0). Treating `<= 0.0` as invalid PTS broke seek operations targeting timestamp 0.0 or keyframes at 0.0s. Furthermore, `frameCount` was not updated during `seekTo()`, so `frameCount / fps` evaluated to pre-seek frame counts.
4. **`sdlffcd_clib.c` PTS Missing Timestamp Fallback**: When `pts == AV_NOPTS_VALUE`, `sdlffcd_video_decode_frame` defaulted `out_frame->pts` to `0.0` instead of trying `best_effort_timestamp` or defaulting to `-1.0` to denote missing timestamps.

## Proposed Changes

### 1. `sdlffcd_clib/sdlffcd_clib.c`
- In `sdlffcd_video_decode_frame`: Check `vctx->frame->pts`; if `AV_NOPTS_VALUE`, check `vctx->frame->best_effort_timestamp`. If still `AV_NOPTS_VALUE`, set `out_frame->pts = -1.0`.

### 2. `source/frame_ring_buffer.d`
- In `FrameRingBuffer.push()`: Check `if (stopRequested || seekRequested)` inside the mutex section after waiting for `notFull`. If `seekRequested` is set, discard the frame and return `false`.

### 3. `source/video_player.d`
- In `VideoPlayer.decodingWorker`: If `!pushed`, check `if (ringBuffer.isStopRequested()) break;` so seek-related push rejections trigger a `continue` rather than breaking out of the worker thread.
- In `VideoPlayer.seekTo(targetPts)`:
  - Reset `frameCount = cast(long)(targetPts * mediaInfo.fps)` to keep frame counts aligned with seek target.
- In `VideoPlayer.update()`:
  - Change condition `if (framePts <= 0.0 && mediaInfo.fps > 0)` to `if (framePts < 0.0 && mediaInfo.fps > 0)`.

### 4. Unit Tests (`source/frame_ring_buffer.d`)
- Add unit tests verifying `FrameRingBuffer` seek request flushing and thread-safe seek signaling behavior.

## Verification Plan
1. Build `sdlffcd` library and application with `dub build`.
2. Run unit tests using `dub test`.
3. Verify video playback and seek/rewind functionality using `samplevideo.mp4`.
