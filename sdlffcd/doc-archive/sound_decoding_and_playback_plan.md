# Implementation Plan - Sound Decoding and Playback

Implement audio stream decoding and audio playback in `sdlffcd` using FFmpeg (`libavcodec` and `libswresample`) and SDL3 (`SDL_AudioStream`).

## User Review Required

> [!NOTE]
> Audio device output will be initialized alongside video in `sdlffcd_app_init` (`SDL_INIT_VIDEO | SDL_INIT_AUDIO`). When playing media files with audio tracks (such as `samplevideo.mp4`), audio is resampled to standard 16-bit stereo PCM and streamed to the default playback device via SDL3 `SDL_AudioStream`.

## Proposed Changes

### 1. C Library Layer (`sdlffcd_clib`)

#### [MODIFY] [sdlffcd_clib.h](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.h)
- Declare new audio management APIs:
  - `bool sdlffcd_video_has_audio(const sdlffcd_VideoContext* vctx)`
  - `bool sdlffcd_video_set_audio_paused(sdlffcd_VideoContext* vctx, bool paused)`
  - `bool sdlffcd_video_is_audio_paused(const sdlffcd_VideoContext* vctx)`
  - `bool sdlffcd_video_clear_audio(sdlffcd_VideoContext* vctx)`
  - `bool sdlffcd_video_set_audio_volume(sdlffcd_VideoContext* vctx, float volume)`
  - `bool sdlffcd_video_get_audio_volume(const sdlffcd_VideoContext* vctx, float* out_volume)`

#### [MODIFY] [sdlffcd_clib_private.h](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib_private.h)
- Include `<libswresample/swresample.h>` and `<libavutil/channel_layout.h>`
- Extend `sdlffcd_VideoContext` struct:
  - `AVFrame* audio_frame`: Reused frame buffer for decoded audio.
  - `SDL_AudioStream* audio_stream`: SDL3 audio stream bound to the default playback device.
  - `struct SwrContext* swr_ctx`: Audio resampler context converting arbitrary source formats/channels/rates to 16-bit stereo PCM.
  - `uint8_t* audio_resample_buf`: Dynamically sized buffer for resampled PCM audio.
  - `int audio_resample_buf_size`: Allocated size of resample buffer.
  - `int audio_target_sample_rate`: Output sample rate (e.g. 44100 or matching input).
  - `int audio_target_channels`: Output channel count (2 for stereo).
  - `double seek_min_audio_pts`: PTS threshold filter during seek pre-rolls.

#### [MODIFY] [sdlffcd_clib.c](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.c)
- Initialize SDL with `SDL_INIT_VIDEO | SDL_INIT_AUDIO` in `sdlffcd_app_init`.
- In `sdlffcd_video_open`:
  - Allocate and open `vctx->audio_codec_ctx` for `vctx->audio_stream_idx`.
  - Configure `SwrContext` using `swr_alloc_set_opts2` to resample source channels/format/rate to stereo `AV_SAMPLE_FMT_S16`.
  - Open `SDL_AudioStream` via `SDL_OpenAudioDeviceStream(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &spec, NULL, NULL)`.
  - Allocate `vctx->audio_frame`.
- In `sdlffcd_video_decode_frame`:
  - Process demuxed audio packets (`pkt->stream_index == vctx->audio_stream_idx`): decode into `vctx->audio_frame`, resample via `swr_convert`, and feed into `vctx->audio_stream` via `SDL_PutAudioStreamData`.
  - Ignore/skip audio frames with PTS before `vctx->seek_min_audio_pts` during seek pre-rolls.
- In `sdlffcd_video_seek`:
  - Flush audio decoder (`avcodec_flush_buffers(vctx->audio_codec_ctx)`).
  - Clear pending audio queue (`SDL_ClearAudioStream(vctx->audio_stream)`).
  - Filter audio during video pre-roll to avoid queuing stale/pre-seek audio.
- In `sdlffcd_video_close`:
  - Clean up `vctx->audio_stream`, `vctx->swr_ctx`, `vctx->audio_resample_buf`, `vctx->audio_frame`, and `vctx->audio_codec_ctx`.
- Implement `sdlffcd_video_has_audio`, `sdlffcd_video_set_audio_paused`, `sdlffcd_video_is_audio_paused`, `sdlffcd_video_clear_audio`, `sdlffcd_video_set_audio_volume`, `sdlffcd_video_get_audio_volume`.

---

### 2. D Language Layer (`source/`)

#### [MODIFY] [source/sdlffcd_clib.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/sdlffcd_clib.d)
- Add exact 1-to-1 D declarations for all new C audio functions.
- Add comprehensive unit tests verifying null safety and function bindings.

#### [MODIFY] [source/video_player.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/video_player.d)
- Integrate audio pause/resume into `VideoPlayer.pause()`, `VideoPlayer.resume()`, and `handlePlayback()`.
- On start of playback, unpause audio stream (`sdlffcd_video_set_audio_paused(vctx, false)`).
- On pause, pause audio stream (`sdlffcd_video_set_audio_paused(vctx, true)`).
- Add audio property accessors (`hasAudio`, `setVolume`, `getVolume`).
- Update unit tests to check audio methods.

---

## Verification Plan

### Automated Tests
- Run full unit test suite:
  ```bash
  dub test
  ```
- Build application binary:
  ```bash
  dub build
  ```

### Manual Verification
- Test audio playback with `samplevideo.mp4`:
  ```bash
  ./sdlffcd samplevideo.mp4
  ```
- Verify:
  - Audio plays clearly in sync with video.
  - Pressing `Space` pauses and resumes both audio and video without drift or clicks.
  - Seeking with `Left` / `Right` (or `[` / `]`) immediately resets audio to the new timestamp without old audio trailing.
  - Looping (`L`) loops audio cleanly between IN and OUT markers.
  - Quitting (`Q` or `Esc`) shuts down cleanly without memory leaks or crashes.
