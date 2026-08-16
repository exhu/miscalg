# Plan: Window Event Refactoring for Window Size Updates

## Goal
Optimize `PlayerController` so that `updateWindowSize` is not invoked every frame in `update()`, but only upon receiving `SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED` and `SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED` events.

## Proposed Changes

### 1. C Bridge Library (`sdlffcd_clib`)
- **`sdlffcd_clib/sdlffcd_clib.h`**:
  - Declare enum `sdlffcd_WindowEvent` with `SDLFFCD_WINDOW_EVENT_NONE`, `SDLFFCD_WINDOW_EVENT_PIXEL_SIZE_CHANGED`, and `SDLFFCD_WINDOW_EVENT_DISPLAY_SCALE_CHANGED`.
  - Declare function pointer type `sdlffcd_WindowEventCallback`.
  - Declare `void sdlffcd_app_set_window_event_callback(sdlffcd_AppContext* app, sdlffcd_WindowEventCallback cb, void* userdata)`.
- **`sdlffcd_clib/sdlffcd_clib_private.h`**:
  - Add `window_event_callback` and `window_event_callback_userdata` fields to `sdlffcd_AppContext`.
- **`sdlffcd_clib/sdlffcd_clib.c`**:
  - Implement `sdlffcd_app_set_window_event_callback`.
  - In `process_single_event` and `window_event_watch`, handle `SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED` in addition to `SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED`.
  - Dispatch window events to registered `window_event_callback`.

### 2. D Bindings (`source/sdlffcd_clib.d`)
- Declare `sdlffcd_WindowEvent`, `sdlffcd_WindowEventCallback`, and `sdlffcd_app_set_window_event_callback` matching `sdlffcd_clib.h` 1-to-1.
- Add assertions in unittests for enum values and null-safety.

### 3. Player Controller (`source/player_controller.d`)
- Remove `updateWindowSize(appContext)` from `update()`.
- Keep initial `updateWindowSize(appContext)` in `initialize()`.
- Add `handleWindowEvent(ref AppContext appContext, sdlffcd_WindowEvent event)` to invoke `updateWindowSize(appContext)` when `SDLFFCD_WINDOW_EVENT_PIXEL_SIZE_CHANGED` or `SDLFFCD_WINDOW_EVENT_DISPLAY_SCALE_CHANGED` is received.
- Add unittests in `player_controller.d` for `handleWindowEvent`.

### 4. Application Main (`source/app.d`)
- Define `handleWindowEvent` C callback and register it via `sdlffcd_app_set_window_event_callback`.

## Verification Plan
1. **Automated Testing**:
   - `dub test` to compile `sdlffcd_clib` and execute all unittests.
2. **Build Test**:
   - `dub build` to verify clean build of the application binary.
