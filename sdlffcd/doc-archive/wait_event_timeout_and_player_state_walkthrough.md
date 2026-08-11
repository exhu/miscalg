# Wait Event Timeout and VideoPlayer Multiple Return State Walkthrough

## Summary of Changes

### 1. C Library (`sdlffcd_clib`) Timeout Extension
- **`sdlffcd_clib/sdlffcd_clib.h`**:
  Updated function signature to accept a `timeout_ms` parameter:
  ```c
  void sdlffcd_app_wait_events(sdlffcd_AppContext* app, int timeout_ms);
  ```
- **`sdlffcd_clib/sdlffcd_clib.c`**:
  Implemented timeout branch logic:
  - `timeout_ms < 0`: calls `SDL_WaitEvent(&event)` (wait indefinitely).
  - `timeout_ms == 0`: calls `SDL_PollEvent(&event)` (non-blocking poll).
  - `timeout_ms > 0`: calls `SDL_WaitEventTimeout(&event, timeout_ms)`.

### 2. D Bindings (`source/sdlffcd_clib.d`)
- Updated binding declaration to match `sdlffcd_clib.h`:
  ```d
  void sdlffcd_app_wait_events(sdlffcd_AppContext* app, int timeout_ms);
  ```

### 3. VideoPlayer Multiple Return State (`source/video_player.d`)
- Introduced `PlayerStatus` enum (`error`, `videoEnd`, `updateAgain`) and `PlayerUpdateState` struct:
  ```d
  enum PlayerStatus { error, videoEnd, updateAgain }
  struct PlayerUpdateState {
      PlayerStatus status;
      int nextUpdateMs;
  }
  ```
- Refactored `VideoPlayer.update(sdlffcd_AppContext* app)`:
  - Returns `PlayerUpdateState.error()` on error or uninitialized context.
  - Returns `PlayerUpdateState.videoEnd()` on EOF.
  - Returns `PlayerUpdateState.updateAgain(nextUpdateMs)` with frame sync delay, pre-fetched next frame delay, or -1 when paused.

### 4. Main Event Loop Update (`source/app.d`)
- Replaced strict polling (`sdlffcd_app_poll_events` + `Thread.sleep(1ms)`) with event wait timeout:
  ```d
  while (sdlffcd_app_is_running(appContext.app))
  {
      auto state = appContext.player.update(appContext.app);
      if (state.isVideoEnd || state.isError) break;
      if (!sdlffcd_app_is_running(appContext.app)) break;
      sdlffcd_app_wait_events(appContext.app, state.nextUpdateMs);
  }
  ```

## Verification Results
- **Unittests**: Executed `dub test` - 3 modules passed unittests.
- **Application Build**: Executed `dub build` - compiled cleanly without warnings.
