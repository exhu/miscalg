# AppContext Refactoring Plan

Move application initialization (`sdlffcd_app_init`, `VideoPlayer` creation) and cleanup (`sdlffcd_app_shutdown`, `VideoPlayer.close`) from `app.d` to `app_context.d`.

## Proposed Changes

### 1. `source/app_context.d`
- Add `init` method to `AppContext` struct:
  - Initializes C SDL application context via `sdlffcd_app_init`.
  - Instantiates `VideoPlayer` object (`new VideoPlayer()`).
- Add `close` method to `AppContext` struct:
  - Closes `VideoPlayer` if instantiated (`player.close()`).
  - Shuts down C SDL application context via `sdlffcd_app_shutdown`.

### 2. `source/app.d`
- Update `main()` function to call `appContext.init(...)` and set `scope(exit) appContext.close()`.
- Access `appContext.player` for video file operations and main loop updates.

## Verification
- Build binary with `dub build`.
