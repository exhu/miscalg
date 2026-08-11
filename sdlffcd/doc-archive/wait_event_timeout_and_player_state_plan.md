# Wait Event Timeout and VideoPlayer Multiple Return State Plan

## Problem & Goal
Currently, `VideoPlayer.update` returns a boolean indicating whether playback is active, and `app.d` performs strict polling using `sdlffcd_app_poll_events` combined with fixed `Thread.sleep(1ms)`.
The goal is to:
1. Extend `sdlffcd_app_wait_events` to accept a `timeout_ms` parameter in C (`sdlffcd_clib`) and update its D binding (`sdlffcd_clib.d`).
2. Update `VideoPlayer.update` to return a `PlayerUpdateState` struct representing multiple states (`error`, `videoEnd`, `updateAgain` with next delay in milliseconds).
3. Use the requested `nextUpdateMs` timeout in `app.d` with `sdlffcd_app_wait_events(app, timeout_ms)` to replace busy polling.

## Proposed Changes

### 1. `sdlffcd_clib/sdlffcd_clib.h` & `sdlffcd_clib/sdlffcd_clib.c`
- Change `sdlffcd_app_wait_events` signature:
  `void sdlffcd_app_wait_events(sdlffcd_AppContext* app, int timeout_ms);`
- Implementation in `sdlffcd_clib.c`:
  - `timeout_ms < 0`: call `SDL_WaitEvent(&event)` (blocking indefinitely).
  - `timeout_ms == 0`: call `SDL_PollEvent(&event)` (non-blocking).
  - `timeout_ms > 0`: call `SDL_WaitEventTimeout(&event, timeout_ms)`.
  - Process all pending events using `process_single_event`.

### 2. `source/sdlffcd_clib.d`
- Update binding:
  `void sdlffcd_app_wait_events(sdlffcd_AppContext* app, int timeout_ms);`

### 3. `source/video_player.d`
- Define `enum PlayerStatus { error, videoEnd, updateAgain }`.
- Define `struct PlayerUpdateState` containing `status` and `nextUpdateMs`.
- Refactor `VideoPlayer.update(sdlffcd_AppContext* app)` to return `PlayerUpdateState`.

### 4. `source/app.d`
- Replace polling loop (`sdlffcd_app_poll_events` + `Thread.sleep`) with:
  - Calling `appContext.player.update(appContext.app)`.
  - Checking `isVideoEnd` or `isError`.
  - Calling `sdlffcd_app_wait_events(appContext.app, state.nextUpdateMs)`.

## Verification Plan
1. Run `dub test` to ensure C library, D bindings, and unittests build and pass.
2. Build and run application (`dub build`, `./sdlffcd samplevideo.mp4` if interactive test or quick invocation) to confirm smooth video playback and event handling.
