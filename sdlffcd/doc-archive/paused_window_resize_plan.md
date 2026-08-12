# Plan: Fix Window Resizing When Video is Paused

## Problem Description
When video playback is paused, the application stops rendering frame updates (`frameRendered` is set to `false` and `nextUpdateMs` is `-1`).
Because `sdlffcd_app_wait_events` processes events but does not trigger a re-render when window resize (`SDL_EVENT_WINDOW_RESIZED`, `SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED`, `SDL_EVENT_WINDOW_EXPOSED`) events occur, the SDL renderer output surface never repaints to match the new window dimensions. To the window manager and user, the window appears unresizable or frozen while paused.

## Proposed Solution
1. **Event Watch & Redraw Flag in C Library (`sdlffcd_clib`)**:
   - Register an event watcher (`SDL_AddEventWatch`) in `sdlffcd_app_init` to catch `SDL_EVENT_WINDOW_RESIZED`, `SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED`, and `SDL_EVENT_WINDOW_EXPOSED` even during OS-modal resize loops.
   - Set a `need_redraw` flag on `sdlffcd_AppContext` when any window resize/expose event is received in `process_single_event` or the event watcher.
   - Provide public C functions: `sdlffcd_app_need_redraw`, `sdlffcd_app_check_and_clear_redraw`, `sdlffcd_app_set_need_redraw`, and `sdlffcd_video_redraw`.
2. **Matching D Bindings (`source/sdlffcd_clib.d`)**:
   - Declare the new C functions in `source/sdlffcd_clib.d`.
   - Add unit tests verifying null-safety for the new binding functions.
3. **Video Player Update Loop (`source/video_player.d`)**:
   - In `VideoPlayer.update`, check if `sdlffcd_app_check_and_clear_redraw` returns `true`.
   - When paused (or waiting for next frame timestamp), if a redraw is requested, call `sdlffcd_video_redraw(app, vctx)` to clear the renderer and redraw the active YUV video texture.
   - Return `PlayerUpdateState.updateAgain(timeout, true)` with `frameRendered = true` so `appContext.renderTimestamp()` redraws the timestamp overlay and presents the updated renderer (`SDL_RenderPresent`).

## Verification Plan
1. Run `dub test` to ensure unit tests pass.
2. Run `dub build` to verify static compilation and C library integration.
