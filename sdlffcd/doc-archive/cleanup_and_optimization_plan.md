# Plan: Codebase Cleanup, Bug Fixes, and Performance Optimizations

Comprehensive plan to eliminate unused functions, data, imports, and dead code; resolve potential bugs in seeking, renderer state, and dynamic format conversion; and apply optimizations in the rendering loop, font rasterization, and text caching.

---

## Proposed Changes

### 1. D Application Cleanup & Dead Code Removal

#### [MODIFY] [source/app.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/app.d)
- Remove unused imports `std.datetime` and `std.string`.

#### [MODIFY] [source/player_controller.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/player_controller.d)
- Remove unused import `std.format`.

#### [MODIFY] [source/observable.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/observable.d)
- Remove unused constant `enum ModelVersion uninitializedVersion = 0;`.

#### [MODIFY] [source/video_player.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/video_player.d)
- Remove redundant duplicate constant `private enum defaultRingBufferCapacity = 8;` (imported from `sdlffcd.frame_ring_buffer`).

#### [MODIFY] [source/player_view.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/player_view.d)
- Remove commented-out dead code `//int dpi = cast(int)(72.0f * displayScale + 0.5f);`.

---

### 2. Performance Optimizations

#### [MODIFY] [source/player_view.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/player_view.d)
- **Display DPI Cache in Font Engine**:
  - Cache `lastDpi` in `View` struct.
  - In `updateDisplayScale()`, return immediately if `dpi == lastDpi` without calling `sdlffcd_font_set_size_dpi()`.
  - Avoids invoking SDL3_ttf font size/DPI re-configuration on every frame update.
- **HUD Text & Size Caching**:
  - Cache `lastCurrentTotalTime` and `lastInOutTime` strings and their measured dimensions (`tsW`, `tsH`, `ioW`, `ioH`) in `View`.
  - Only invoke `sdlffcd_text_set_string()` and `sdlffcd_text_get_size()` when the text string value actually changes, rather than on every frame render.

---

### 3. Bug Fixes & Robustness Improvements in `sdlffcd_clib`

#### [MODIFY] [sdlffcd_clib/sdlffcd_clib.c](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.c)
- **Header Inclusions**:
  - Remove unused `#include "SDL3/SDL_oldnames.h"`.
  - Remove inline mid-file `#include <libavutil/imgutils.h>` (moved to `sdlffcd_clib_private.h`).
- **Renderer State Bug in `sdlffcd_app_present`**:
  - Remove spurious `SDL_SetRenderDrawColor(app->renderer, 255, 32, 40, 255);` from `sdlffcd_app_present()` to avoid polluting active draw color.
- **Robust Timestamp Calculation in `sdlffcd_video_seek`**:
  - Use `av_rescale_q((int64_t)(target_pts_seconds * AV_TIME_BASE), AV_TIME_BASE_Q, vst->time_base)` instead of floating-point division `(int64_t)(target_pts_seconds / av_q2d(vst->time_base))` to prevent potential division by zero and timestamp drift.
- **Dynamic Dimension Handling in `sdlffcd_video_render_frame`**:
  - When frame dimensions change (`vctx->texture_width != frame->width || vctx->texture_height != frame->height`), properly free and invalidate any cached `vctx->sws_ctx` and `vctx->sws_data[0]` so software conversion cleanly re-allocates buffers for the new dimensions.
- **Documentation Comments**:
  - Fix swapped comments on letterbox vs. pillarbox in `sdlffcd_update_letterbox_rect`.

#### [MODIFY] [sdlffcd_clib/sdlffcd_clib_private.h](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib_private.h)
- Include `<libavutil/imgutils.h>` in private header alongside other FFmpeg headers.

---

### 4. Documentation Updates

#### [MODIFY] [README.md](file:///home/yur/agy-projects/miscalg/sdlffcd/README.md)
- Add missing `M` (`Toggle audio mute / unmute`) control to the controls table in `README.md`.

---

## Verification Plan

### Automated Tests
1. **D Unit Tests**:
   ```bash
   dub test
   ```
   Verify that all unit tests in all 7 modules pass cleanly without errors.

2. **D & C Build**:
   ```bash
   dub build
   ```
   Verify that `meson compile` for `libsdlffcd_clib.a` and `ldc2` build for `sdlffcd` succeed cleanly without warnings or link errors.

### Manual Verification
1. **Interactive Playback & Seeking**:
   ```bash
   ./sdlffcd --quit samplevideo.mp4
   ```
   - Verify smooth video playback and audio.
   - Verify seeking forward/backward (`Left`/`Right`), start/end (`B`/`E`), frame stepping (`[`/`]`).
   - Verify IN/OUT markers (`I`/`O`/`Shift+I`/`Shift+O`) and looping (`L`).
   - Verify time position HUD toggle (`V`), fullscreen toggle (`F`), mute toggle (`M`), and cut command generation (`Enter`).
