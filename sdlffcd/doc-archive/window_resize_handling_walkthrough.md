# Walkthrough: Window Resize Handling in PlayerController

Added window resize handling to `PlayerController` to automatically update the view model's width and height when the application window is resized, ensuring timestamp overlay positioning remains correct for all position modes (`topRight`, `bottomRight`, `bottomLeft`, `topLeft`).

## Changes Made

### 1. C Bridge Library (`sdlffcd_clib`)

#### `sdlffcd_clib/sdlffcd_clib.h`
- Added declaration for `sdlffcd_app_get_window_size`:
  ```c
  /// Get current window size in pixels/logical units. Returns false on invalid context or error.
  bool sdlffcd_app_get_window_size(const sdlffcd_AppContext* app, int* out_w, int* out_h);
  ```

#### `sdlffcd_clib/sdlffcd_clib.c`
- Implemented `sdlffcd_app_get_window_size`:
  ```c
  bool sdlffcd_app_get_window_size(const sdlffcd_AppContext* app, int* out_w, int* out_h) {
      if (!app || !app->window || !out_w || !out_h) return false;
      return SDL_GetWindowSize(app->window, out_w, out_h);
  }
  ```

### 2. D Bindings (`source/sdlffcd_clib.d`)

- Added `extern(C)` function declaration matching `sdlffcd_clib.h`:
  ```d
  bool sdlffcd_app_get_window_size(const(sdlffcd_AppContext)* app, int* out_w, int* out_h);
  ```
- Added null-check assertion in `unittest`:
  ```d
  assert(!sdlffcd_app_get_window_size(null, null, null));
  ```

### 3. Player Controller (`source/player_controller.d`)

- Added `updateWindowSize(ref AppContext appContext)` method:
  ```d
  void updateWindowSize(ref AppContext appContext)
  {
    if (appContext.app !is null)
    {
      int w = 0, h = 0;
      if (sdlffcd_app_get_window_size(appContext.app, &w, &h) && w > 0 && h > 0)
      {
        viewModel.windowWidth = w;
        viewModel.windowHeight = h;
      }
    }
  }
  ```
- Updated `initialize()` and `update()` to invoke `updateWindowSize(appContext)`.
- Added `if (viewModel.pollUpdate()) dirty = true;` inside `PlayerController.update()` so that changes to `viewModel` (such as window width/height updates or timestamp position changes) trigger a view render call (`view.render(appContext.app, viewModel)`).
- Added `unittest` verifying `Tracked!ViewModel` window dimensions and `pollUpdate()` behavior.

## Verification

- Executed `dub test`:
  ```bash
  6 modules passed unittests
  ```
- Executed `dub build`:
  - Built `sdlffcd_clib` static library and `sdlffcd` binary cleanly without warnings or errors.
