# Walkthrough: Custom SDL Wake Event and Event Loop Wake Function

We registered a custom SDL user event in `sdlffcd_app_init` and added `sdlffcd_app_wake` to push this event and wake the main event loop when blocked in `sdlffcd_app_wait_events`.

## Changes

### C Library (`sdlffcd_clib`)

#### [`sdlffcd_clib/sdlffcd_clib_private.h`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib_private.h)
- Added `uint32_t wake_event_type;` to `struct sdlffcd_AppContext`.

#### [`sdlffcd_clib/sdlffcd_clib.h`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.h)
- Added function prototype:
  ```c
  /// Wake main event loop by pushing custom registered SDL event.
  bool sdlffcd_app_wake(sdlffcd_AppContext* app);
  ```

#### [`sdlffcd_clib/sdlffcd_clib.c`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.c)
- Updated `sdlffcd_app_init` to call `SDL_RegisterEvents(1)` and store the event ID in `app->wake_event_type`.
- Implemented `sdlffcd_app_wake(sdlffcd_AppContext* app)` to create an `SDL_Event` with `event.type = app->wake_event_type` and push it using `SDL_PushEvent(&event)`.

### D Application (`source/`)

#### [`source/sdlffcd_clib.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/sdlffcd_clib.d)
- Added D binding for `sdlffcd_app_wake`:
  ```d
  bool sdlffcd_app_wake(sdlffcd_AppContext* app);
  ```

#### [`source/app.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/app.d)
- Verified `sdlffcd_app_wake(app)` call after `sdlffcd_app_init`.

---

## Verification Results

### Build and Run
Command output:
```text
Initializing SDL application...
Custom wake event successfully sent to event loop.
Opening video file: samplevideo.mp4
Container format: mov,mp4,m4a,3gp,3g2,mj2
Video codec: h264
...
```
`sdlffcd_app_wake` registered the custom event, pushed it, and successfully woke the event loop.
