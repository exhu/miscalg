# Walkthrough: Split `sdlffcd_clib` into SDL and FFmpeg Bridge Libraries

Split the monolithic C bridge library `sdlffcd_clib` into two decoupled, standalone C99 static libraries:
1. **`sdlffcd_sdl` (`libsdlffcd_sdl.a`)**: SDL3 window management, event loop, rendering, audio device playback streaming, font/text management (SDL3_ttf), and logging.
2. **`sdlffcd_ffmpeg` (`libsdlffcd_ffmpeg.a`)**: FFmpeg media container demuxing, video stream decoding, audio stream decoding, audio resampling to standard 16-bit stereo PCM, and PTS seeking.

---

## Architecture Overview

```mermaid
graph TD
    subgraph D_App [D Application Layer]
        App[app.d / app_context.d]
        Player[video_player.d]
        RingBuf[frame_ring_buffer.d]
        PView[player_view.d]
        SdlLog[sdl_logger.d]
    end

    subgraph DBindings [D Binding Modules]
        DSdl[source/sdlffcd_sdl.d]
        DFFmpeg[source/sdlffcd_ffmpeg.d]
        DCompat[source/sdlffcd_clib.d (compat facade)]
    end

    subgraph CLibs [C Bridge Libraries (C99)]
        subgraph SDL_Bridge [sdlffcd_sdl]
            CSdlH[sdlffcd_sdl.h]
            CSdlC[sdlffcd_sdl.c]
        end
        subgraph FFmpeg_Bridge [sdlffcd_ffmpeg]
            CFFH[sdlffcd_ffmpeg.h]
            CFFC[sdlffcd_ffmpeg.c]
        end
    end

    subgraph ThirdParty [Third-Party Dependencies]
        SDL3[SDL3 & SDL3_ttf]
        FFmpeg[libavformat, libavcodec, libavutil, libswscale, libswresample]
    end

    App --> DSdl
    PView --> DSdl
    SdlLog --> DSdl
    Player --> DSdl
    Player --> DFFmpeg
    RingBuf --> DFFmpeg
    DCompat -.-> DSdl
    DCompat -.-> DFFmpeg

    DSdl --> CSdlH
    DFFmpeg --> CFFH

    CSdlC --> SDL3
    CFFC --> FFmpeg
```

---

## Changes Made

### 1. C Bridge Libraries (`sdlffcd_clib/`)
- **SDL Bridge Library**:
  - [sdlffcd_sdl.h](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_sdl.h) & [sdlffcd_sdl_private.h](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_sdl_private.h) & [sdlffcd_sdl.c](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_sdl.c): Created SDL3-specific APIs for application lifecycle, key/window events, `sdlffcd_VideoRenderer` (YUV texture rendering and letterboxing), `sdlffcd_AudioStream` (audio device stream playback & gain control), fonts, text objects, and logging.
- **FFmpeg Bridge Library**:
  - [sdlffcd_ffmpeg.h](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_ffmpeg.h) & [sdlffcd_ffmpeg_private.h](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_ffmpeg_private.h) & [sdlffcd_ffmpeg.c](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_ffmpeg.c): Created pure FFmpeg APIs for opening media files, querying `sdlffcd_MediaInfo`, setting audio sample callbacks (`sdlffcd_video_set_audio_callback`), decoding video frames (`sdlffcd_video_decode_frame`), and frame-accurate seeking (`sdlffcd_video_seek`).
- **Meson Build**:
  - [meson.build](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/meson.build): Configured two separate static library targets: `sdlffcd_sdl` and `sdlffcd_ffmpeg`.
- **Cleanup**: Removed obsolete monolithic files `sdlffcd_clib.c`, `sdlffcd_clib.h`, and `sdlffcd_clib_private.h`.

### 2. D Bindings & Build Configuration
- [source/sdlffcd_sdl.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/sdlffcd_sdl.d): 1-to-1 D declarations matching `sdlffcd_sdl.h` with comprehensive unit tests.
- [source/sdlffcd_ffmpeg.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/sdlffcd_ffmpeg.d): 1-to-1 D declarations matching `sdlffcd_ffmpeg.h` with struct size and null-safety unit tests.
- [source/sdlffcd_clib.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/sdlffcd_clib.d): Updated to re-export `sdlffcd.sdlffcd_sdl` and `sdlffcd.sdlffcd_ffmpeg` for backward compatibility.
- [dub.json](file:///home/yur/agy-projects/miscalg/sdlffcd/dub.json): Configured `sourceFiles` and `extraDependencyFiles` to link both `libsdlffcd_sdl.a` and `libsdlffcd_ffmpeg.a`.

### 3. Application Integration
- [source/video_player.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/video_player.d):
  - Updated `VideoPlayer` to hold `sdlffcd_VideoContext*` (FFmpeg decoder), `sdlffcd_VideoRenderer*` (SDL video presenter), and `sdlffcd_AudioStream*` (SDL audio stream).
  - Connected audio delivery from FFmpeg decoder to SDL playback stream via `sdlffcd_video_set_audio_callback`.
  - Updated video presentation to use `sdlffcd_video_renderer_draw_yuv` and `sdlffcd_video_renderer_redraw`.

---

## Verification Results

### Automated Tests
- `dub test --force`:
  ```
  INFO: calculating backend command to run: /usr/bin/ninja -C /home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/_build
  ninja: Entering directory `/home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/_build'
  ninja: no work to do.
  Starting Performing "unittest" build using /home/yur/dlang/ldc-1.42.0/bin/ldc2 for x86_64.
  Building sdlffcd ~master: building configuration [sdlffcd-test-library]
  Linking sdlffcd-test-library
  Running sdlffcd-test-library 
  8 modules passed unittests
  ```

### Build Verification
- `dub build --force`:
  ```
  Building sdlffcd ~master: building configuration [application]
  Linking sdlffcd
  ```
  Executable `./sdlffcd` was successfully built and linked against both static libraries.
