# Implementation Plan - SDL3_ttf Text Drawing & Video Playback Timestamp Display

Implement text drawing functions in `sdlffcd_clib` using SDL3_ttf's `TTF_CreateRendererTextEngine()`. To maximize performance, allocated text objects (`sdlffcd_Text`) reuse underlying GPU textures and internal engine structures across consecutive calls via `TTF_SetTextString()`. Test the feature by displaying a timestamp overlay (`HH:MM:SS.msec / HH:MM:SS.msec`) rendered via `AppContext` during video playback using font `fonts/GoogleSansCode-Regular.ttf` at size 19pt with white ink and a solid black background rectangle.

## User Review Required

> [!IMPORTANT]
> **Separation of Concerns**: `VideoPlayer` remains strictly responsible for video decoding and frame rendering onto `app->renderer`. It reports whether a frame was drawn via `state.frameRendered` in `PlayerUpdateState` and exposes `getCurrentPts()` and `getDuration()`.

> [!NOTE]
> **Encapsulation in `AppContext`**: The `AppContext` D struct in `app_context.d` will own and manage `timestampFont` (`fonts/GoogleSansCode-Regular.ttf` at 19pt) and `timestampText`. `AppContext` will provide `renderTimestamp()`, which queries playback position and duration from `VideoPlayer`, formats `HH:MM:SS.msec / HH:MM:SS.msec`, updates `timestampText` string via `sdlffcd_text_set_string` (reusing textures/buffers), draws the text with a black background rectangle via `sdlffcd_text_draw_with_bg`, and presents the renderer via `sdlffcd_app_present`.

## Proposed Changes

### `sdlffcd_clib` (C Library Layer)

#### [MODIFY] `sdlffcd_clib/meson.build`
- Add `sdlttf_dep` to `deps` so that `sdlffcd_clib` links against `libSDL3_ttf`.

#### [MODIFY] `sdlffcd_clib/sdlffcd_clib_private.h`
- `#include <SDL3_ttf/SDL_ttf.h>`
- Add `TTF_TextEngine* text_engine` field to `struct sdlffcd_AppContext`.
- Define opaque struct representations `struct sdlffcd_Font` and `struct sdlffcd_Text`.

#### [MODIFY] `sdlffcd_clib/sdlffcd_clib.h`
- Declare `typedef struct sdlffcd_Font sdlffcd_Font;` and `typedef struct sdlffcd_Text sdlffcd_Text;`.
- Declare text API functions:
  - `sdlffcd_Font* sdlffcd_font_open(const char* filepath, float ptsize)`
  - `void sdlffcd_font_close(sdlffcd_Font* font)`
  - `sdlffcd_Text* sdlffcd_text_create(sdlffcd_AppContext* app, sdlffcd_Font* font, const char* text)`
  - `bool sdlffcd_text_set_string(sdlffcd_Text* text_obj, const char* new_text)`
  - `bool sdlffcd_text_set_color(sdlffcd_Text* text_obj, uint8_t r, uint8_t g, uint8_t b, uint8_t a)`
  - `bool sdlffcd_text_get_size(const sdlffcd_Text* text_obj, int* out_w, int* out_h)`
  - `bool sdlffcd_text_draw(sdlffcd_Text* text_obj, float x, float y)`
  - `bool sdlffcd_text_draw_with_bg(sdlffcd_AppContext* app, sdlffcd_Text* text_obj, float x, float y, uint8_t bg_r, uint8_t bg_g, uint8_t bg_b, uint8_t bg_a, float padding)`
  - `void sdlffcd_text_destroy(sdlffcd_Text* text_obj)`
  - `void sdlffcd_app_present(sdlffcd_AppContext* app)`

#### [MODIFY] `sdlffcd_clib/sdlffcd_clib.c`
- Initialize `TTF_Init()` and `TTF_CreateRendererTextEngine(app->renderer)` in `sdlffcd_app_init`.
- Clean up `TTF_DestroyRendererTextEngine` and `TTF_Quit()` in `sdlffcd_app_shutdown`.
- Implement `sdlffcd_font_open` / `sdlffcd_font_close`.
- Implement `sdlffcd_text_create`, `sdlffcd_text_set_string` (using `TTF_SetTextString` for texture/data reuse), `sdlffcd_text_set_color`, `sdlffcd_text_get_size`, `sdlffcd_text_draw`, `sdlffcd_text_draw_with_bg`, and `sdlffcd_text_destroy`.
- Update `sdlffcd_video_render_frame` to copy frame texture to renderer without calling `SDL_RenderPresent`.
- Implement `sdlffcd_app_present`.

---

### D Application Layer

#### [MODIFY] `source/sdlffcd_clib.d`
- Add `struct sdlffcd_Font;` and `struct sdlffcd_Text;`.
- Add `extern(C)` declarations for font/text functions and `sdlffcd_app_present`.
- Add unit tests verifying `sdlffcd_clib` text API declarations.

#### [MODIFY] `source/video_player.d`
- Add `bool frameRendered` field to `PlayerUpdateState` (and static factory methods `updateAgain(int nextUpdateMs, bool frameRendered = false)`).
- Set `frameRendered = true` when `sdlffcd_video_render_frame` is called.
- Ensure `getCurrentPts()` and `getDuration()` methods are available to query playback timestamps.

#### [MODIFY] `source/app_context.d`
- Add `sdlffcd_Font* timestampFont` and `sdlffcd_Text* timestampText` fields to `AppContext`.
- Update `AppContext.init()` to open `fonts/GoogleSansCode-Regular.ttf` at size 19pt, create `timestampText`, and set text color to white `(255, 255, 255, 255)`.
- Implement helper function `formatTimestamp(double currentPts, double lastFrameTime)` producing string format `HH:MM:SS.msec / HH:MM:SS.msec`.
- Implement `AppContext.renderTimestamp()` method:
  1. Retrieves `currentPts = player.getCurrentPts()` and `duration = player.getDuration()`.
  2. Formats timestamp string via `formatTimestamp`.
  3. Updates `timestampText` string via `sdlffcd_text_set_string`.
  4. Draws text with black background rectangle via `sdlffcd_text_draw_with_bg(app, timestampText, 10.0f, 10.0f, 0, 0, 0, 255, 4.0f)`.
  5. Presents renderer via `sdlffcd_app_present(app)`.
- Update `AppContext.close()` to call `sdlffcd_text_destroy(timestampText)` and `sdlffcd_font_close(timestampFont)`.
- Add unit tests for `formatTimestamp`.

#### [MODIFY] `source/app.d`
- In the main event loop, when `state.frameRendered` is true, call `appContext.renderTimestamp()`.

## Verification Plan

### Automated Tests
- Build C library with Meson:
  ```bash
  PKG_CONFIG_PATH="$HOME/.local/lib/pkgconfig:$PKG_CONFIG_PATH" meson compile -C sdlffcd_clib/_build
  ```
- Run D unit tests with DUB:
  ```bash
  dub test
  ```

### Manual Verification
- Launch video playback with `samplevideo.mp4`:
  ```bash
  ./sdlffcd samplevideo.mp4
  ```
- Verify:
  1. Timestamp label is displayed in top-left corner of video window.
  2. Timestamp is formatted as `HH:MM:SS.msec / HH:MM:SS.msec` (e.g. `00:00:01.234 / 00:00:09.960`).
  3. Text color is white, 19pt size using `fonts/GoogleSansCode-Regular.ttf`.
  4. Background is a solid black rectangle behind text.
  5. Timestamp updates smoothly during playback, pause (`Space`/`P`), and seeking (`R`/`F`/arrows).
