# Walkthrough: Fix Window Resizing When Video is Paused

## Changes Made

### C Library (`sdlffcd_clib`)
- **`sdlffcd_clib_private.h`**: Added `bool need_redraw;` flag to `struct sdlffcd_AppContext` (adjusting padding `uint8_t _pad[2]`).
- **`sdlffcd_clib.h`**: Declared new public API functions:
  - `sdlffcd_app_need_redraw`
  - `sdlffcd_app_check_and_clear_redraw`
  - `sdlffcd_app_set_need_redraw`
  - `sdlffcd_video_redraw`
- **`sdlffcd_clib.c`**:
  - Registered `SDL_AddEventWatch(window_event_watch, app)` during `sdlffcd_app_init` to catch `SDL_EVENT_WINDOW_RESIZED`, `SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED`, and `SDL_EVENT_WINDOW_EXPOSED` events during OS modal window drag-resizing.
  - Set `app->need_redraw = true` in `process_single_event` and `window_event_watch` upon receiving window resize/expose events.
  - Implemented `sdlffcd_video_redraw` to clear the renderer and render the active YUV video texture (`vctx->texture`) mapped to the updated renderer viewport.
  - Removed event watch on `sdlffcd_app_shutdown`.

### D Language Bindings (`source/sdlffcd_clib.d`)
- Added C function bindings matching `sdlffcd_clib.h`.
- Added unit tests for null safety of the new bindings.

### Video Player (`source/video_player.d`)
- Updated `VideoPlayer.update` so that when `paused` (or waiting for next frame timestamp), it checks `sdlffcd_app_check_and_clear_redraw(app)`.
- If a redraw is requested while paused, it calls `sdlffcd_video_redraw(app, vctx)` and returns `PlayerUpdateState.updateAgain(-1, true)` (`frameRendered = true`).
- This causes `appContext.renderTimestamp()` to run in `app.d`, re-rendering the timestamp overlay and calling `sdlffcd_app_present(app)` (`SDL_RenderPresent`) to present the updated window contents instantly.
- Added `redraw(app)` helper method to `VideoPlayer` and corresponding unit test.

## Verification
- Ran `dub test`: All 4 test modules compiled and passed.
- Ran `dub build`: Binary linked successfully with C static library.
