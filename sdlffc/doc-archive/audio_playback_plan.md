# Implementation Plan - Audio Playback Support

Implement audio demuxing, decoding, resampling (`SwrContext`), and output using SDL3's `SDL_AudioStream` API in `sdlffc`.

## Goal Description
The `sdlffc` video player currently decodes and renders video frames, but discards audio streams. This feature adds full audio playback support:
- Finding and opening the best audio stream using FFmpeg (`AVMEDIA_TYPE_AUDIO`).
- Decoding audio packets in parallel with video packet demuxing.
- Resampling audio frames (e.g. from planar float `AV_SAMPLE_FMT_FLTP` to packed `AV_SAMPLE_FMT_F32` or `S16`) using `libswresample`.
- Feeding audio buffers into an `SDL_AudioStream` attached to the default playback device.
- Pausing/resuming audio playback synchronously with video when pressing Space.
- Flushing audio buffers and decoders during seek operations.

---

## User Review Required

> [!IMPORTANT]
> **Dependency Addition**: `libswresample` will be added to `meson.build` dependencies. `libswresample` is a standard component of FFmpeg included with `libavcodec-dev`.

> [!NOTE]
> **A/V Sync**: Audio playback is managed by SDL3's hardware audio stream, while video frame presentation uses the existing `play_start_time` clock. Pausing/resuming toggles `SDL_PauseAudioStreamDevice` / `SDL_ResumeAudioStreamDevice`, and seeking calls `SDL_ClearAudioStream` to flush pending audio samples instantly.

---

## Open Questions
None at this time. Requirements for audio playback, pause/resume, and seek integration are clearly defined.

---

## Proposed Changes

### Build Configuration

#### [MODIFY] [meson.build](file:///home/yur/agy-projects/miscalg/sdlffc/meson.build)
- Add `libswresample_dep = dependency('libswresample')` to `deps`.
- Include `#include <libswresample/swresample.h>` header access.

---

### Data Structures & Headers

#### [MODIFY] [sdlffclib_private.h](file:///home/yur/agy-projects/miscalg/sdlffc/sdlffclib_private.h)
- Include `<libswresample/swresample.h>`.
- Add audio context pointers to `SdlffVideoFileContext`:
  ```c
  SwrContext *swr_ctx;
  AVFrame *audio_frame;
  ```
- Add `SDL_AudioStream *audio_stream;` to `_SdlffContext`.

---

### Core Audio Implementation

#### [MODIFY] [sdlffclib.c](file:///home/yur/agy-projects/miscalg/sdlffc/sdlffclib.c)

1. **Audio Stream Opening (`open_audio_stream`)**:
   - Locate audio stream with `av_find_best_stream(ic, AVMEDIA_TYPE_AUDIO, -1, -1, &codec, 0)`.
   - Allocate and configure `AVCodecContext` for audio.
   - Create `SDL_AudioStream` targeting `SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK` with `SDL_AUDIO_F32` (or `S16`) format matching output rate/channels.

2. **Resampling & Playback**:
   - Initialize `SwrContext` via `swr_alloc_set_opts2` to convert decoded frames into packed float32 samples.
   - In the demux loop / video thread, when reading an audio packet:
     - Decode with `avcodec_send_packet` / `avcodec_receive_frame`.
     - Resample audio frame into output buffer using `swr_convert`.
     - Push resampled PCM data into `context->audio_stream` via `SDL_PutAudioStreamData`.

3. **Pause / Resume Integration**:
   - When Space toggles pause state:
     - On pause: call `SDL_PauseAudioStreamDevice(context->audio_stream)`.
     - On resume: call `SDL_ResumeAudioStreamDevice(context->audio_stream)`.

4. **Seek & Cleanup Integration**:
   - On seek (`handle_seek`):
     - Flush `audio_context` using `avcodec_flush_buffers`.
     - Clear pending audio samples with `SDL_ClearAudioStream(context->audio_stream)`.
   - On cleanup (`sdlffclib_free_video_file_ctx` and `sdlffclib_done`):
     - Destroy `SDL_AudioStream` using `SDL_DestroyAudioStream`.
     - Free `SwrContext` using `swr_free`.
     - Free `audio_frame`.

---

## Verification Plan

### Automated Build & Compile
Run `./build.sh` to compile the refactored code with `-Werror` / strict C99 checks.

```bash
./build.sh
```

### Manual Verification
1. Launch `./_build/sdlffc samplevideo.mp4` to play video with sound.
2. Confirm audio plays in sync with video.
3. Press **Space** to pause: verify both video and audio pause instantly.
4. Press **Space** to resume: verify audio resumes seamlessly.
5. Press **Left / Right Arrow** to seek: verify audio flushes cleanly and resumes playing from the new position without stutter or residual audio artifacts.
