# Plan: Introduce Event Loop Wake Functionality

## Objective
Register a custom SDL event during `sdlffcd_app_init` and introduce `sdlffcd_app_wake` to wake the main event loop when blocked in `sdlffcd_app_wait_events`.

---

## Detailed Plan

### 1. `sdlffcd_clib/sdlffcd_clib_private.h`
- Add `uint32_t wake_event_type` field to `struct sdlffcd_AppContext`.

### 2. `sdlffcd_clib/sdlffcd_clib.h`
- Declare `bool sdlffcd_app_wake(sdlffcd_AppContext* app);` function prototype.

### 3. `sdlffcd_clib/sdlffcd_clib.c`
- In `sdlffcd_app_init`:
  - Call `SDL_RegisterEvents(1)` to obtain a custom user event type.
  - Store it in `app->wake_event_type`.
- Implement `bool sdlffcd_app_wake(sdlffcd_AppContext* app)`:
  - Return `false` if `app` is `NULL` or `wake_event_type` is invalid (`(uint32_t)-1`).
  - Zero-initialize an `SDL_Event`, set `event.type = app->wake_event_type`, and call `SDL_PushEvent(&event)`.

### 4. `source/sdlffcd_clib.d`
- Add matching C binding:
  ```d
  bool sdlffcd_app_wake(sdlffcd_AppContext* app);
  ```

### 5. `source/app.d`
- Add a test thread or verification call to `sdlffcd_app_wake(app)` to confirm event loop wake up works.

---

## Verification Plan

1. Rebuild `sdlffcd_clib` library and D application with `dub build`.
2. Run `./sdlffcd samplevideo.mp4` to ensure playback and clean shutdown work as expected.
