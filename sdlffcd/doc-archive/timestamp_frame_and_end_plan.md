# Implementation Plan: Frame Numbers and [END] Badge Display

Add frame numbers `(Frame X/Y)` and an `[END]` status badge to `formattedCurrentTotalTime` to clarify playback progress and clearly indicate when playback reaches the end of the video.

## Proposed Changes

### `source/models.d`
- Update `PlayerFields` to store `currentFrame`, `totalFrames`, and `isEnd`:
  ```d
  struct PlayerFields
  {
    bool isPaused;
    bool isLooping;
    bool isMuted;
    bool isEnd;
    double timePosition;
    double timeDuration;
    long currentFrame;
    long totalFrames;
  }
  ```
- Update `formatTimestamp`:
  ```d
  string formatTimestamp(
    double posSec,
    double totalSec,
    long currentFrame = 0,
    long totalFrames = 0,
    bool isLooping = false,
    bool isPaused = false,
    bool isMuted = false,
    bool isEnd = false)
  ```
  - Format output string as `%02d:%02d:%02d.%03d / %02d:%02d:%02d.%03d (Frame %d/%d)` when `totalFrames > 0`.
  - Append badges in order: `[LOOP]`, `[END]`, `[PAUSED]`, `[MUTE]`.
- Update unittests in `models.d` to verify frame formatting and `[END]` indicator.

---

### `source/video_player.d`
- Add `atEnd` boolean field to `VideoPlayer`:
  - Set `atEnd = true` when `SDLFFCD_DECODE_EOF` is received.
  - Reset `atEnd = false` when `seekTo()`, `rewind()`, or replay occurs.
- Add helper methods:
  - `bool isAtEnd() const`: returns `atEnd`.
  - `long getTotalFrames() const`: returns `mediaInfo.num_frames > 0 ? mediaInfo.num_frames : cast(long)(mediaInfo.duration_seconds * mediaInfo.fps + 0.5)`.
  - `long getCurrentFrame() const`: returns 1-based frame index derived from `currentPts` and `fps`, clamped between `1` and `totalFrames` (or `totalFrames` if `atEnd`).

---

### `source/player_controller.d`
- In `PlayerController.update()`:
  - Synchronize `playerModel.isEnd = appContext.player.isAtEnd();`
  - Synchronize `playerModel.currentFrame = appContext.player.getCurrentFrame();`
  - Synchronize `playerModel.totalFrames = appContext.player.getTotalFrames();`
  - Pass the updated frame numbers and `isEnd` flag to `formatTimestamp()`.

---

## Verification Plan

### Automated Tests
- Run `dub test` to execute all unittests in `models.d` and other modules.

### Build Verification
- Run `dub build` to verify clean compilation.

### Manual Playback Verification
- Run `./sdlffcd samplevideo.mp4`
- Observe initial frame: `(Frame 1/...)`
- Observe playback until end: verify `(Frame N/N)` and `[END] [PAUSED]` appear when playback reaches the end.
- Verify seek / frame stepping / rewind clears `[END]`.
