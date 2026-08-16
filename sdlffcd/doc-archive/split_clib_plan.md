# Plan: Split `sdlffcd_clib` into SDL and FFmpeg Bridge Libraries

Split the monolithic C wrapper `sdlffcd_clib` into two distinct, decoupled C bridge libraries:
1. **SDL Bridge Library (`sdlffcd_sdl`)**: Exposes SDL3 and SDL3_ttf functionality (windowing, event handling, font/text rendering, logging, video texture rendering, and audio stream playback).
2. **FFmpeg Bridge Library (`sdlffcd_ffmpeg`)**: Exposes FFmpeg functionality (container demuxing, video/audio stream decoding, PTS extraction, seeking, audio resampling, and pixel format conversion).

Neither C library will depend on the other.

---

## User Review Required

> [!IMPORTANT]
> **Decoupled Audio & Video Interfaces**:
> Currently, `sdlffcd_VideoContext` manages both FFmpeg contexts and SDL resources (`SDL_Texture*`, `SDL_AudioStream*`).
> In this split:
> - `sdlffcd_ffmpeg` will handle pure FFmpeg decoding, outputting raw video frames (`sdlffcd_VideoFrame`) and resampled PCM audio buffers via an audio callback or queue.
> - `sdlffcd_sdl` will manage windowing, `sdlffcd_VideoRenderer` (SDL texture rendering), `sdlffcd_AudioStream` (SDL audio device playback), fonts, text, and logging.
> - The D application (`VideoPlayer` / `FrameRingBuffer`) coordinates passing decoded frames to `sdlffcd_VideoRenderer` and resampled audio to `sdlffcd_AudioStream`.

> [!NOTE]
> **Directory & Library Layout**:
> The `sdlffcd_clib/` directory will build two static libraries via Meson:
> - `libsdlffcd_sdl.a` with `sdlffcd_sdl.h` / `sdlffcd_sdl_private.h`
> - `libsdlffcd_ffmpeg.a` with `sdlffcd_ffmpeg.h` / `sdlffcd_ffmpeg_private.h`
>
> On the D side, `source/sdlffcd_sdl.d` and `source/sdlffcd_ffmpeg.d` will maintain 1-to-1 declarations with the C headers. A compatibility module `source/sdlffcd_clib.d` will publicly import both to ensure seamless transitions.

---

## Architecture Diagram

```mermaid
graph TD
    subgraph D_Application [D Application Layer]
        App[app.d / app_context.d]
        Player[video_player.d]
        RingBuf[frame_ring_buffer.d]
        PView[player_view.d]
        SdlLog[sdl_logger.d]
    end

    subgraph DBindings [D Binding Modules]
        DSdl[sdlffcd_sdl.d]
        DFFmpeg[sdlffcd_ffmpeg.d]
        DCompat[sdlffcd_clib.d (compat facade)]
    end

    subgraph CLibraries [C Bridge Libraries (C99)]
        subgraph SDL_Bridge [sdlffcd_sdl]
            CSdlH[sdlffcd_sdl.h]
            CSdlC[sdlffcd_sdl.c]
        end
        subgraph FFmpeg_Bridge [sdlffcd_ffmpeg]
            CFFH[sdlffcd_ffmpeg.h]
            CFFC[sdlffcd_ffmpeg.c]
        end
    end

    subgraph SystemDependencies [Third-Party Dependencies]
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

## Proposed Changes

### Component 1: C Bridge Libraries (`sdlffcd_clib/`)

#### [NEW] `sdlffcd_clib/sdlffcd_sdl.h` & `sdlffcd_clib/sdlffcd_sdl_private.h` & `sdlffcd_clib/sdlffcd_sdl.c`
- **Window & Lifecycle API**:
  - `sdlffcd_AppContext* sdlffcd_app_init(const char* title, int width, int height);`
  - `void sdlffcd_app_shutdown(sdlffcd_AppContext* app);`
  - `bool sdlffcd_app_is_running(const sdlffcd_AppContext* app);`
  - `void sdlffcd_app_stop(sdlffcd_AppContext* app);`
  - `void sdlffcd_app_poll_events(sdlffcd_AppContext* app);`
  - `void sdlffcd_app_wait_events(sdlffcd_AppContext* app, int timeout_ms);`
  - `bool sdlffcd_app_wake(sdlffcd_AppContext* app);`
  - `void sdlffcd_app_render(sdlffcd_AppContext* app);`
  - `void sdlffcd_app_present(sdlffcd_AppContext* app);`
  - `bool sdlffcd_app_get_window_size(const sdlffcd_AppContext* app, int* out_w, int* out_h);`
  - `float sdlffcd_app_get_display_scale(const sdlffcd_AppContext* app);`
  - `bool sdlffcd_app_toggle_fullscreen(sdlffcd_AppContext* app);`
  - `bool sdlffcd_app_is_fullscreen(const sdlffcd_AppContext* app);`
  - `bool sdlffcd_app_need_redraw(const sdlffcd_AppContext* app);`
  - `bool sdlffcd_app_check_and_clear_redraw(sdlffcd_AppContext* app);`
  - `void sdlffcd_app_set_need_redraw(sdlffcd_AppContext* app, bool need_redraw);`
  - Callbacks and Enums: `sdlffcd_Key`, `sdlffcd_KeyMod`, `sdlffcd_KeyCallback`, `sdlffcd_WindowEvent`, `sdlffcd_WindowEventCallback`.
- **Video Renderer API**:
  - `typedef struct sdlffcd_VideoRenderer sdlffcd_VideoRenderer;`
  - `sdlffcd_VideoRenderer* sdlffcd_video_renderer_create(sdlffcd_AppContext* app);`
  - `bool sdlffcd_video_renderer_draw_yuv(sdlffcd_AppContext* app, sdlffcd_VideoRenderer* vr, const uint8_t* const data[8], const int linesize[8], int width, int height);`
  - `bool sdlffcd_video_renderer_redraw(sdlffcd_AppContext* app, sdlffcd_VideoRenderer* vr);`
  - `void sdlffcd_video_renderer_destroy(sdlffcd_VideoRenderer* vr);`
- **Audio Stream Playback API**:
  - `typedef struct sdlffcd_AudioStream sdlffcd_AudioStream;`
  - `sdlffcd_AudioStream* sdlffcd_audio_stream_open(int sample_rate, int channels);`
  - `bool sdlffcd_audio_stream_put_data(sdlffcd_AudioStream* stream, const void* data, int len);`
  - `bool sdlffcd_audio_stream_set_paused(sdlffcd_AudioStream* stream, bool paused);`
  - `bool sdlffcd_audio_stream_is_paused(const sdlffcd_AudioStream* stream);`
  - `bool sdlffcd_audio_stream_clear(sdlffcd_AudioStream* stream);`
  - `bool sdlffcd_audio_stream_set_volume(sdlffcd_AudioStream* stream, float volume);`
  - `bool sdlffcd_audio_stream_get_volume(const sdlffcd_AudioStream* stream, float* out_volume);`
  - `void sdlffcd_audio_stream_close(sdlffcd_AudioStream* stream);`
- **Text & Font API**:
  - `sdlffcd_Font* sdlffcd_font_open(const char* filepath, float ptsize);`
  - `bool sdlffcd_font_set_hinting(sdlffcd_Font* font, sdlffcd_FontHinting hinting);`
  - `sdlffcd_FontHinting sdlffcd_font_get_hinting(const sdlffcd_Font* font);`
  - `bool sdlffcd_font_set_size_dpi(sdlffcd_Font* font, float ptsize, int hdpi, int vdpi);`
  - `void sdlffcd_font_close(sdlffcd_Font* font);`
  - `sdlffcd_Text* sdlffcd_text_create(sdlffcd_AppContext* app, sdlffcd_Font* font, const char* text);`
  - `bool sdlffcd_text_set_string(sdlffcd_Text* text_obj, const char* new_text);`
  - `bool sdlffcd_text_set_color(sdlffcd_Text* text_obj, uint8_t r, uint8_t g, uint8_t b, uint8_t a);`
  - `bool sdlffcd_text_get_size(const sdlffcd_Text* text_obj, int* out_w, int* out_h);`
  - `bool sdlffcd_text_draw(sdlffcd_Text* text_obj, float x, float y);`
  - `bool sdlffcd_text_draw_with_bg(sdlffcd_AppContext* app, sdlffcd_Text* text_obj, float x, float y, uint8_t bg_r, uint8_t bg_g, uint8_t bg_b, uint8_t bg_a, float padding);`
  - `void sdlffcd_text_destroy(sdlffcd_Text* text_obj);`
- **Logging API**:
  - `void sdlffcd_log_message(int category, sdlffcd_LogPriority priority, const char* message);`
  - `void sdlffcd_log_set_all_priority(sdlffcd_LogPriority priority);`

#### [NEW] `sdlffcd_clib/sdlffcd_ffmpeg.h` & `sdlffcd_clib/sdlffcd_ffmpeg_private.h` & `sdlffcd_clib/sdlffcd_ffmpeg.c`
- **FFmpeg Decoding & Media API**:
  - `typedef struct sdlffcd_VideoContext sdlffcd_VideoContext;`
  - `typedef struct sdlffcd_MediaInfo sdlffcd_MediaInfo;`
  - `typedef struct sdlffcd_VideoFrame sdlffcd_VideoFrame;`
  - `typedef enum sdlffcd_DecodeStatus sdlffcd_DecodeStatus;`
  - `sdlffcd_VideoContext* sdlffcd_video_open(const char* filename);`
  - `bool sdlffcd_video_get_media_info(const sdlffcd_VideoContext* vctx, sdlffcd_MediaInfo* out_info);`
  - `sdlffcd_DecodeStatus sdlffcd_video_decode_frame(sdlffcd_VideoContext* vctx, sdlffcd_VideoFrame* out_frame);`
  - `bool sdlffcd_video_seek(sdlffcd_VideoContext* vctx, double target_pts_seconds);`
  - `void sdlffcd_video_close(sdlffcd_VideoContext* vctx);`
  - `bool sdlffcd_video_has_audio(const sdlffcd_VideoContext* vctx);`
  - Audio delivery callback:
    - `typedef void (*sdlffcd_AudioPacketCallback)(void* userdata, const uint8_t* pcm_data, int byte_len);`
    - `void sdlffcd_video_set_audio_callback(sdlffcd_VideoContext* vctx, sdlffcd_AudioPacketCallback cb, void* userdata);`

#### [MODIFY] `sdlffcd_clib/meson.build`
- Split dependencies into `sdl_deps = [sdl_dep, sdlttf_dep, m_dep]` and `ffmpeg_deps = [libavutil_dep, libavcodec_dep, libavformat_dep, libswscale_dep, libswresample_dep, m_dep]`.
- Define two static library targets:
  ```meson
  lib_sdl = static_library('sdlffcd_sdl', ['sdlffcd_sdl.c'], dependencies: sdl_deps)
  lib_ffmpeg = static_library('sdlffcd_ffmpeg', ['sdlffcd_ffmpeg.c'], dependencies: ffmpeg_deps)
  ```

---

### Component 2: Build & D Bindings Layer

#### [MODIFY] `dub.json`
- Update `sourceFiles` and `extraDependencyFiles` to reference `libsdlffcd_sdl.a` and `libsdlffcd_ffmpeg.a`.
- Update `preGenerateCommands` to compile both targets.

#### [NEW] `source/sdlffcd_sdl.d`
- 1-to-1 D declarations matching `sdlffcd_sdl.h` with full null-safety unittests.

#### [NEW] `source/sdlffcd_ffmpeg.d`
- 1-to-1 D declarations matching `sdlffcd_ffmpeg.h` with unittests for struct layouts and null checks.

#### [MODIFY] `source/sdlffcd_clib.d`
- Re-export `public import sdlffcd.sdlffcd_sdl;` and `public import sdlffcd.sdlffcd_ffmpeg;` for smooth compatibility.

---

### Component 3: Application Code Integration

#### [MODIFY] `source/video_player.d`
- `VideoPlayer` holds `sdlffcd_VideoContext*` (FFmpeg bridge), `sdlffcd_VideoRenderer*` (SDL bridge), and `sdlffcd_AudioStream*` (SDL bridge).
- When initializing audio, opens `sdlffcd_audio_stream_open(mediaInfo.sample_rate, 2)`.
- Passes audio callback to `sdlffcd_video_set_audio_callback` which puts resampled PCM samples into the `sdlffcd_AudioStream`.
- In `handlePlayback` / `redraw`, delegates frame presentation to `sdlffcd_video_renderer_draw_yuv` and `sdlffcd_video_renderer_redraw`.

#### [MODIFY] `source/player_view.d` & `source/sdl_logger.d` & `source/app_context.d` & `source/app.d`
- Update imports to use `sdlffcd.sdlffcd_sdl` (or `sdlffcd.sdlffcd_clib`).

---

## Verification Plan

### Automated Tests
- Run `dub test` to compile both C libraries (`libsdlffcd_sdl.a`, `libsdlffcd_ffmpeg.a`) and run all D unittests.
- Run `dub build` to verify executable compilation and linking.

### Manual Playback Verification
- Run `./sdlffcd samplevideo.mp4`
- Verify video playback and audio synchronization.
- Test seeking (forward `]`/`F`, backward `[`/`B`, rewind/fast-forward).
- Test spacebar pause/resume, volume change (`+`/`-`), mute (`M`).
- Test window resizing and fullscreen toggle (`F`).
- Test timestamp and in/out markers overlay.
