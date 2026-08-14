# Walkthrough - Sound Decoding and Playback

Sound decoding and audio playback have been implemented in `sdlffcd` using FFmpeg (`libavcodec` and `libswresample`) and SDL3 (`SDL_AudioStream`).

## Changes

### 1. C Library (`sdlffcd_clib`)
- **[sdlffcd_clib.h](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.h)**:
  - Added public audio API declarations:
    - [`sdlffcd_video_has_audio`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.h#L165)
    - [`sdlffcd_video_set_audio_paused`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.h#L168)
    - [`sdlffcd_video_is_audio_paused`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.h#L171)
    - [`sdlffcd_video_clear_audio`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.h#L174)
    - [`sdlffcd_video_set_audio_volume`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.h#L177)
    - [`sdlffcd_video_get_audio_volume`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.h#L180)
- **[sdlffcd_clib_private.h](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib_private.h)**:
  - Included `<libswresample/swresample.h>` and `<libavutil/channel_layout.h>`.
  - Added audio playback and resampling fields to `sdlffcd_VideoContext` (`audio_frame`, `audio_stream`, `swr_ctx`, `audio_resample_buf`, `audio_target_sample_rate`, `audio_target_channels`, `audio_volume`, `seek_min_audio_pts`).
- **[sdlffcd_clib.c](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.c)**:
  - Initialized SDL subsystem with `SDL_INIT_VIDEO | SDL_INIT_AUDIO` in `sdlffcd_app_init`.
  - Initialized audio codec context and configured `SwrContext` resampler (`swr_alloc_set_opts2`) and `SDL_OpenAudioDeviceStream` in `sdlffcd_video_open`.
  - Decoded and resampled audio packets in `process_audio_packet` / `sdlffcd_video_decode_frame`, streaming PCM directly to `SDL_PutAudioStreamData`.
  - Added audio buffer flush and pre-roll threshold filtering in `sdlffcd_video_seek`.
  - Handled cleanup of audio resources (`SDL_DestroyAudioStream`, `swr_free`, `audio_resample_buf`, `audio_frame`, `audio_codec_ctx`) in `sdlffcd_video_close`.
  - Implemented all audio API functions.

### 2. D Language Application (`source/`)
- **[sdlffcd_clib.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/sdlffcd_clib.d)**:
  - Added 1-to-1 D declarations for all audio API symbols.
  - Added unit test cases testing null safety for audio functions.
- **[video_player.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/video_player.d)**:
  - Synchronized audio stream state with video playback: unpausing audio when starting/resuming playback, pausing on pause/seek.
  - Added audio helper properties `hasAudio`, `setVolume`, `getVolume`.
  - Added unit tests for audio methods on uninitialized/unloaded players.
  - Fixed loop mode audio glitches by immediately setting `currentPts = targetPts` and clearing the audio stream in `seekTo`, preventing seek event spamming across frames while waiting for decoded slots and flushing leftover resampler state (`swr_init`).

---

## Verification Results

### Automated Tests
- `dub test` passed with all 7 modules passing unit tests:
  ```
  7 modules passed unittests
  ```
- `dub build` built the binary successfully.

### Playback Verification
- Executed `./sdlffcd --quit samplevideo.mp4` to playback completion:
  ```
  Initializing SDL application...
  VideoPlayer: Opening video file: samplevideo.mp4
  Container format: mov,mp4,m4a,3gp,3g2,mj2
  Video codec: h264
  Audio codec: aac
  Resolution: 464x848
  Duration: 8.90 sec, FPS: 30.00, Frames: 267
  Starting main event loop...
  VideoPlayer: Reached end of video stream.
  Playback finished (end of video stream). Quitting...
  Exited cleanly.
  ```
