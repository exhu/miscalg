# Walkthrough: Frame Numbers & [END] Status Indicator

Implemented frame count display `(Frame X/Y)` and an explicit `[END]` status indicator in `formattedCurrentTotalTime` to provide video editing clarity and resolve ambiguity when playback reaches the end of the video.

## Summary of Changes

### 1. `source/models.d`
- Extended `PlayerFields` with `currentFrame`, `totalFrames`, and `isEnd`.
- Updated `formatTimestamp()` to:
  - Output `%02d:%02d:%02d.%03d / %02d:%02d:%02d.%03d (Frame %d/%d)` when `totalFrames > 0`.
  - Append `[END]` status badge when `isEnd` is true.
  - Retain formatting for `[LOOP]`, `[PAUSED]`, and `[MUTE]`.
- Updated module unittests with test cases covering frame numbers and `[END]` badge combinations.

### 2. `source/video_player.d`
- Added `atEnd` state tracking to `VideoPlayer`:
  - Set to `true` upon reaching EOF (`SDLFFCD_DECODE_EOF` or decoder thread termination).
  - Automatically reset to `false` upon seek, rewind, or new file load.
  - Automatically seeks to `0.0` when unpausing from `atEnd` state.
- Added public getters:
  - `isAtEnd()`: returns boolean EOF state.
  - `getTotalFrames()`: returns stream total frame count from `mediaInfo.num_frames` or `duration_seconds * fps`.
  - `getCurrentFrame()`: returns 1-based current frame index, clamped to `[1, totalFrames]`, or `totalFrames` if at EOF.

### 3. `source/player_controller.d`
- Synchronized `playerModel.isEnd`, `playerModel.currentFrame`, and `playerModel.totalFrames` from `appContext.player`.
- Passed the frame numbers and `isEnd` flag to `formatTimestamp()`.

---

## Verification Results

### Automated Tests
Ran `dub test`:
```
$ dub test
...
7 modules passed unittests
```

### Build Verification
Ran `dub build`:
```
$ dub build
...
Linking sdlffcd
Build succeeded.
```

### Format Output Example
- Normal playback: `00:00:01.000 / 00:00:10.000 (Frame 25/250)`
- Paused on last frame at EOF: `00:00:09.960 / 00:00:10.000 (Frame 250/250) [END] [PAUSED]`
- Looping playback: `00:00:05.000 / 00:00:10.000 (Frame 125/250) [LOOP]`
