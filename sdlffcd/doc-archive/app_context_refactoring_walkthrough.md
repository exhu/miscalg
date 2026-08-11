# AppContext Refactoring Walkthrough

## Summary of Changes

Moved `sdlffcd_app_init`, `sdlffcd_app_shutdown`, and `VideoPlayer` creation/cleanup logic into methods on `AppContext` in `source/app_context.d`.

## Changes Made

### `source/app_context.d`
- Added `init()` method that invokes `sdlffcd_app_init` and creates `new VideoPlayer()`.
- Added `close()` method that invokes `VideoPlayer.close()` and `sdlffcd_app_shutdown()`.

### `source/app.d`
- Simplified `main()` initialization to `appContext.init()` with `scope(exit) appContext.close()`.
- Updated main event loop references from `player` to `appContext.player`.

## Verification Results

### Build Verification
- Executed `dub build` successfully.
