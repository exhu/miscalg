# Plan: Window Resize Handling in PlayerController

Add window resize handling to `PlayerController` to dynamically update the view model's width and height so that calculated timestamp overlay positions (e.g. `topRight`, `bottomRight`, `bottomLeft`) remain accurate when the application window is resized.

## Proposed Changes

### 1. C Bridge Library (`sdlffcd_clib`)
- Add `bool sdlffcd_app_get_window_size(const sdlffcd_AppContext* app, int* out_w, int* out_h)` function signature to `sdlffcd_clib/sdlffcd_clib.h`.
- Implement `sdlffcd_app_get_window_size` in `sdlffcd_clib/sdlffcd_clib.c` using `SDL_GetWindowSize`.

### 2. D Bindings (`source/sdlffcd_clib.d`)
- Declare `bool sdlffcd_app_get_window_size(const(sdlffcd_AppContext)* app, int* out_w, int* out_h);` in `source/sdlffcd_clib.d`.
- Add null-check unittest in `source/sdlffcd_clib.d`.

### 3. PlayerController (`source/player_controller.d`)
- Add helper method `void updateWindowSize(ref AppContext appContext)` to query current window dimensions via `sdlffcd_app_get_window_size` and update `viewModel.windowWidth` and `viewModel.windowHeight`.
- Call `updateWindowSize(appContext)` during `initialize()` and at the start of `update()`.
- Add `viewModel.pollUpdate()` check to `update()` so that changes in `viewModel` (including window width/height) set `dirty = true`, triggering `view.render(appContext.app, viewModel)`.
- Add unittests in `source/player_controller.d` verifying model window dimensions and `pollUpdate()` behavior.

## Verification Plan

### Automated Verification
- Run `dub test` to compile `sdlffcd_clib` and execute all D unittests.

### Manual Verification
- Run video playback with `samplevideo.mp4`.
- Resize the window during playback and while paused.
- Cycle timestamp positions using `T` key and verify `topRight`, `bottomRight`, `bottomLeft`, and `topLeft` timestamp positions track window boundaries accurately.
