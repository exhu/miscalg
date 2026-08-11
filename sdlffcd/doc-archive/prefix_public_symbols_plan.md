# Plan: Prefix Public Symbols in `sdlffcd_clib` with `sdlffcd_`

## Goal
Ensure all public symbols exported by the `sdlffcd_clib` C library and bound in D (`source/sdlffcd_clib.d`) follow the naming convention of having a `sdlffcd_` prefix.

---

## Changes Required

### 1. [`sdlffcd_clib/sdlffcd_clib.h`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.h)
- Rename `AppContext` -> `sdlffcd_AppContext`
- Rename `app_init` -> `sdlffcd_app_init`
- Rename `app_is_running` -> `sdlffcd_app_is_running`
- Rename `app_wait_events` -> `sdlffcd_app_wait_events`
- Rename `app_render` -> `sdlffcd_app_render`
- Rename `app_shutdown` -> `sdlffcd_app_shutdown`

### 2. [`sdlffcd_clib/sdlffcd_clib_private.h`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib_private.h)
- Update internal struct definition: `struct AppContext` -> `struct sdlffcd_AppContext`

### 3. [`sdlffcd_clib/sdlffcd_clib.c`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.c)
- Update function signatures and type references to match `sdlffcd_AppContext` and `sdlffcd_app_*`.

### 4. [`source/sdlffcd_clib.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/sdlffcd_clib.d)
- Update D external declarations to match `sdlffcd_clib.h`:
  - `struct sdlffcd_AppContext;`
  - `sdlffcd_AppContext* sdlffcd_app_init(...)`
  - `bool sdlffcd_app_is_running(...)`
  - `void sdlffcd_app_wait_events(...)`
  - `void sdlffcd_app_render(...)`
  - `void sdlffcd_app_shutdown(...)`

### 5. [`source/app.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/app.d)
- Update D application code calling the library functions.

---

## Verification Plan

1. Run `dub build` to rebuild `sdlffcd_clib` via Meson and compile/link `sdlffcd`.
2. Run `dub test` or `./sdlffcd` to verify clean build and execution.
