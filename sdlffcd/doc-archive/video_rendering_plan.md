# Implementation Plan: Video Frame Rendering and Texture Reuse

Add video frame rendering functions to `sdlffcd_clib` with `SDL_Texture` reuse encapsulated inside `sdlffcd_VideoContext`, and update `source/app.d` to initialize SDL before opening and playing video files.

---

## Architecture Overview

```mermaid
flowchart TD
    subgraph D Application (source/app.d)
        A["main()"] -->|"1. Initialize SDL Window/Renderer"| B["sdlffcd_app_init()"]
        A -->|"2. Call decode_video_file(app, filename)"| C["decode_video_file()"]
        C -->|"3. Open Video File"| D["sdlffcd_video_open()"]
        C -->|"4. Loop: Decode Frame"| E["sdlffcd_video_decode_frame()"]
        C -->|"5. Loop: Render Frame"| F["sdlffcd_video_render_frame()"]
        C -->|"6. Loop: Poll Events & Frame Timing"| G["sdlffcd_app_is_running() / SDL_Delay()"]
        C -->|"7. Close Video"| H["sdlffcd_video_close()"]
        A -->|"8. Shutdown SDL"| I["sdlffcd_app_shutdown()"]
    end
    subgraph C Bridge (sdlffcd_clib)
        F -->|"Checks/recreates streaming texture"| J["sdlffcd_VideoContext->texture (SDL_Texture*)"]
        F -->|"Updates YUV texture data"| K["SDL_UpdateYUVTexture() / sws_scale()"]
        F -->|"Renders texture to screen"| L["SDL_RenderTexture() & SDL_RenderPresent()"]
        H -->|"Frees SDL_Texture & SwsContext"| J
    end
```

---

## User Review Required

> [!IMPORTANT]
> - `SDL_Texture*` will be owned and managed by `sdlffcd_VideoContext`. It is created on the first call to `sdlffcd_video_render_frame` (or recreated if frame dimensions change) and destroyed in `sdlffcd_video_close`.
> - `sdlffcd_app_init` will be called at application startup in `main()`. `decode_video_file` will take `(sdlffcd_AppContext* app, string filename)`.

---

## Proposed Changes

### Component: C Bridge (`sdlffcd_clib`)

#### [MODIFY] [`sdlffcd_clib/sdlffcd_clib_private.h`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib_private.h)
Add texture and conversion context fields to `struct sdlffcd_VideoContext` with explicit lifetime comments:
```c
struct sdlffcd_VideoContext {
    AVFormatContext* fmt_ctx;
    AVCodecContext* video_codec_ctx;
    AVCodecContext* audio_codec_ctx;
    int video_stream_idx;
    int audio_stream_idx;
    AVFrame* frame;
    AVPacket* pkt;
    sdlffcd_MediaInfo info;

    /* Reused hardware rendering resources (lifetime managed by vctx until sdlffcd_video_close) */
    SDL_Texture* texture;        /* Owned by vctx; created on demand and destroyed in sdlffcd_video_close */
    int texture_width;           /* Width of current vctx->texture in pixels */
    int texture_height;          /* Height of current vctx->texture in pixels */

    /* Software format conversion context (lifetime managed by vctx until sdlffcd_video_close) */
    struct SwsContext* sws_ctx;  /* Owned by vctx; allocated when pixel format conversion is required */
    uint8_t* sws_data[4];        /* Pointers to sws conversion output plane buffers owned by vctx */
    int sws_linesize[4];         /* Pitches/strides for sws conversion plane buffers */
};
```

#### [MODIFY] [`sdlffcd_clib/sdlffcd_clib.h`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.h)
Declare the rendering function with pointer lifetime doc comments:
```c
/**
 * Render a decoded video frame to the SDL renderer using the cached texture stored in vctx.
 *
 * Pointer lifetime semantics:
 * - `app` and `vctx` must remain valid, initialized context pointers for the duration of the call.
 * - `frame` and its plane data pointers (`frame->data`) reference frame buffer memory managed by `vctx`.
 *   The `frame` struct and data pointers are only guaranteed valid until the next call to `sdlffcd_video_decode_frame`
 *   or `sdlffcd_video_close`. `sdlffcd_video_render_frame` does not retain `frame` pointer references after returning.
 * - The internal `SDL_Texture` pointer is owned and managed by `vctx` and freed during `sdlffcd_video_close`.
 *
 * @param app Pointer to initialized sdlffcd_AppContext.
 * @param vctx Pointer to opened sdlffcd_VideoContext.
 * @param frame Pointer to decoded sdlffcd_VideoFrame to render.
 * @return true on successful render, false on error.
 */
bool sdlffcd_video_render_frame(sdlffcd_AppContext* app, sdlffcd_VideoContext* vctx, const sdlffcd_VideoFrame* frame);
```

#### [MODIFY] [`sdlffcd_clib/sdlffcd_clib.c`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.c)
1. Implement `sdlffcd_video_render_frame`:
   - Verify `app`, `app->renderer`, `vctx`, and `frame`.
   - Check if `vctx->texture` needs creation/recreation (if `NULL` or width/height changed).
   - Use `SDL_CreateTexture(app->renderer, SDL_PIXELFORMAT_IYUV, SDL_TEXTUREACCESS_STREAMING, frame->width, frame->height)`.
   - If frame is `AV_PIX_FMT_YUV420P` or `AV_PIX_FMT_YUVJ420P`, update via `SDL_UpdateYUVTexture`.
   - Otherwise, convert using `sws_scale` to `AV_PIX_FMT_YUV420P` and update texture.
   - Render texture with `SDL_RenderClear`, `SDL_RenderTexture`, and `SDL_RenderPresent`.
2. Update `sdlffcd_video_close`:
   - Destroy `vctx->texture` with `SDL_DestroyTexture`.
   - Free `vctx->sws_ctx` with `sws_freeContext` and free any allocated `sws_data` plane buffers.

---

### Component: D Bindings (`source/sdlffcd_clib.d`)

#### [MODIFY] [`source/sdlffcd_clib.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/sdlffcd_clib.d)
Add `extern(C)` declaration:
```d
bool sdlffcd_video_render_frame(sdlffcd_AppContext* app, sdlffcd_VideoContext* vctx, const(sdlffcd_VideoFrame)* frame);
```

---

### Component: D Application (`source/app.d`)

#### [MODIFY] [`source/app.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/app.d)
1. Change `decode_video_file` signature to `void decode_video_file(sdlffcd_AppContext* app, string filename)`.
2. In `decode_video_file` decoding loop:
   - Call `sdlffcd_video_render_frame(app, vctx, &frame)`.
   - Add frame delay/rate regulation based on `info.fps` (or ~33ms for 30fps) so playback is smooth.
   - Poll events and break if user requested quit (`!sdlffcd_app_is_running(app)`).
3. In `main`:
   - Initialize SDL first with `sdlffcd_AppContext* app = sdlffcd_app_init("SDLFFCD Video Player", info.width ? info.width : 800, info.height ? info.height : 600)` (or dynamic window resolution).
   - Pass `app` into `decode_video_file(app, filename)`.
   - Shutdown SDL on exit with `sdlffcd_app_shutdown(app)`.

---

## Verification Plan

### Automated Build Verification
Run the build script to compile `sdlffcd_clib` and the D application:
```bash
dub build
```

### Manual Verification
Run the video player with sample video file:
```bash
./sdlffcd samplevideo.mp4
```
Verify:
1. SDL window opens with title "SDLFFCD Video Player".
2. Video frames from `samplevideo.mp4` render smoothly in real time.
3. Closing the window or pressing `Q`/`ESC` terminates cleanly without crashes or memory leaks.
