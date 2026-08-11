# Walkthrough: Prefix Public Symbols in `sdlffcd_clib` with `sdlffcd_`

All public C symbols exported by `sdlffcd_clib` and exposed to D via `source/sdlffcd_clib.d` have been updated with the `sdlffcd_` prefix.

## Summary of Changes

### C Library (`sdlffcd_clib`)
- [`sdlffcd_clib/sdlffcd_clib.h`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.h):
  - Renamed `AppContext` to `sdlffcd_AppContext`
  - Renamed functions to `sdlffcd_app_init`, `sdlffcd_app_is_running`, `sdlffcd_app_wait_events`, `sdlffcd_app_render`, `sdlffcd_app_shutdown`.
- [`sdlffcd_clib/sdlffcd_clib_private.h`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib_private.h):
  - Updated private struct declaration to `struct sdlffcd_AppContext`.
- [`sdlffcd_clib/sdlffcd_clib.c`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.c):
  - Updated all function definitions and internal context variable references.

### D Application (`source`)
- [`source/sdlffcd_clib.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/sdlffcd_clib.d):
  - Updated external C bindings to match `sdlffcd_clib.h`.
- [`source/app.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/app.d):
  - Updated application main loop logic to call `sdlffcd_` prefixed functions.

---

## Verification Results

### Automated Build Verification
Ran `dub build`:
- `libsdlffcd_clib.a` static library compiled cleanly via Meson & Ninja.
- `sdlffcd` application compiled and linked cleanly with `ldc2`.
