# Walkthrough: Window Event Refactoring for Window Size Updates

Refactored `updateWindowSize` invocation in `PlayerController` to be event-driven instead of polling on every frame during `update()`.

## Changes

### 1. C Bridge Library (`sdlffcd_clib`)
- [`sdlffcd_clib/sdlffcd_clib.h`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.h):
  - Defined `sdlffcd_WindowEvent` enum (`SDLFFCD_WINDOW_EVENT_NONE`, `SDLFFCD_WINDOW_EVENT_PIXEL_SIZE_CHANGED`, `SDLFFCD_WINDOW_EVENT_DISPLAY_SCALE_CHANGED`).
  - Added `sdlffcd_WindowEventCallback` type.
  - Declared `sdlffcd_app_set_window_event_callback`.
- [`sdlffcd_clib/sdlffcd_clib_private.h`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib_private.h):
  - Added `window_event_callback` and `window_event_callback_userdata` to `sdlffcd_AppContext`.
- [`sdlffcd_clib/sdlffcd_clib.c`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.c):
  - Implemented `sdlffcd_app_set_window_event_callback`.
  - Updated `process_single_event` and `window_event_watch` to handle `SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED` and dispatch `SDLFFCD_WINDOW_EVENT_PIXEL_SIZE_CHANGED` and `SDLFFCD_WINDOW_EVENT_DISPLAY_SCALE_CHANGED` events to `window_event_callback`.

### 2. D Bindings (`source/sdlffcd_clib.d`)
- [`source/sdlffcd_clib.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/sdlffcd_clib.d):
  - Added matching 1-to-1 D declarations for `sdlffcd_WindowEvent`, `sdlffcd_WindowEventCallback`, and `sdlffcd_app_set_window_event_callback`.
  - Added unit test assertions verifying enum values and null-safety.

### 3. Player Controller (`source/player_controller.d`)
- [`source/player_controller.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/player_controller.d):
  - Removed per-frame `updateWindowSize(appContext)` from `update()`.
  - Added `handleWindowEvent(ref AppContext appContext, sdlffcd_WindowEvent event)` that calls `updateWindowSize(appContext)` only on pixel size changed and display scale changed events.
  - Added unit tests for `handleWindowEvent`.

### 4. Application Entry Point (`source/app.d`)
- [`source/app.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/app.d):
  - Defined `handleWindowEvent` C-linkage callback.
  - Registered window event callback with `sdlffcd_app_set_window_event_callback`.

## Verification Results

### Automated Unit Tests
Executed `dub test` - all 7 modules passed unittests:
```bash
dub test
# 7 modules passed unittests
```

### Application Build
Executed `dub build` - compiled and linked successfully without errors or warnings.
