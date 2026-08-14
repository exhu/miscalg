# Plan: Timestamp Display at Video End & Comparison with Video Editors

## Problem Analysis

Currently, `formattedCurrentTotalTime` formats timestamps as:
```
00:00:09.960 / 00:00:10.000 [PAUSED]
```

### Why this happens
1. **Frame PTS vs. Stream Duration**: In digital video (FFmpeg/SDL), every frame represents a discrete time interval $[t_{\text{start}}, t_{\text{end}})$ of length $\Delta t = \frac{1}{\text{fps}}$.
2. **Last Frame Start Time**: For a 10.0-second video at 25 fps, the last frame starts at $t = 10.0 - 0.04 = 9.960\,\text{s}$ and ends at $10.000\,\text{s}$.
3. **The Confusion**: When playback finishes and pauses on the last frame, `currentPts` is `09.960s` while `duration` is `10.000s`. The user sees `00:00:09.960 / 00:00:10.000`, making it look like playback stopped 40ms before the end or failed to finish.

---

## How Video Editors and Players Handle This Case

Professional NLEs (Non-Linear Editors) and video trimming/playback tools address this in several standard ways:

### 1. Dedicated Trimming & NLE Tools (LosslessCut, Avidemux, VirtualDub, Premiere, DaVinci Resolve)
* **Frame Numbers & Total Frames**:
  - Editors always display the frame number alongside timecode: e.g. `Frame 240 / 240` (1-indexed) or `Frame 239 / 239` (0-indexed).
  - This immediately confirms to the editor that they are viewing the final frame of the clip.
* **SMPTE Timecode (`HH:MM:SS:FF`)**:
  - In 25 fps, the final frame is `00:00:09:24` (frame 25 out of 25) with sequence duration `00:00:10:00`.
* **Explicit Playback State Badges**:
  - LosslessCut and VirtualDub indicate EOF status (e.g. `[EOF]`, `[END]`, or `100%`).

### 2. Media Players (VLC, mpv, QuickTime, YouTube)
* **End-of-Playback Clamping**: When the player reaches the end of the stream and stops, the playhead time display is clamped to the total duration (`00:00:10.000 / 00:00:10.000`).
* **Remaining Time Mode**: Players often allow toggling the right side to display negative remaining time (`-00:00:00.000` when at the end).

---

## Recommended Improvement Options for `sdlffcd`

We can implement one or a combination of the following options:

### Option A: `[END]` Status Badge (Recommended)
* **Behavior**:
  - When the video reaches EOF (or `currentPts >= lastFrameTime` with EOF reached), append an `[END]` badge (similar to `[LOOP]`, `[PAUSED]`, `[MUTE]`).
  - Example: `00:00:09.960 / 00:00:10.000 [END] [PAUSED]`
* **Pros**: Preserves exact frame PTS precision (critical for video cut/trim operations) while explicitly signaling that the whole video has completed.

### Option B: Frame Number Display (`Frame Cur/Total`)
* **Behavior**:
  - Add frame count information: `00:00:09.960 / 00:00:10.000 (Frame 250/250) [PAUSED]`
* **Pros**: Invaluable for video editing and trimming, clear 1-to-1 confirmation of reaching the final frame.

### Option C: Playhead Interval End / Clamping at EOF
* **Behavior**:
  - When reaching the end of the video, display the duration as current time: `00:00:10.000 / 00:00:10.000 [PAUSED]`.
* **Pros**: Familiar consumer video player behavior (VLC / YouTube style).
* **Cons**: Less accurate for frame-by-frame cut verification unless paired with frame numbers.
