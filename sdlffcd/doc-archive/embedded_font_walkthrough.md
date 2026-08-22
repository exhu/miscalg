# Embedded Font Loading Walkthrough

## Summary of Changes

Updated `sdlffcd_font_open` to open fonts directly from memory buffers using `SDL_IOFromConstMem` and `TTF_OpenFontIO`, enabling `source/player_view.d` to load font glyphs from embedded binary data (`regularFontData`).

## Changes Made

### 1. C Bridge Library (`sdlffcd_clib`)
- **[sdlffcd_clib/sdlffcd_sdl.h](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_sdl.h)**:
  - Added `#include <stddef.h>` for `size_t`.
  - Changed `sdlffcd_font_open(const char* filepath, float ptsize)` to `sdlffcd_font_open(const void* data, size_t data_size, float ptsize)`.
- **[sdlffcd_clib/sdlffcd_sdl.c](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_sdl.c)**:
  - Replaced `TTF_OpenFont` with `SDL_IOFromConstMem(data, data_size)` + `TTF_OpenFontIO(io, true, ptsize)`.

### 2. D Bindings & View
- **[source/sdlffcd_sdl.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/sdlffcd_sdl.d)**:
  - Synchronized `sdlffcd_font_open` declaration: `sdlffcd_Font* sdlffcd_font_open(const(void)* data, size_t data_size, float ptsize);`.
  - Updated null-check unit test to pass `sdlffcd_font_open(null, 0, 12.0f)`.
- **[source/player_view.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/player_view.d)**:
  - In `View.initialize`, replaced the placeholder font opening call with `sdlffcd_font_open(regularFontData.ptr, regularFontData.length, 19.0f)`.
  - Added a unit test validating `regularFontData` embedded data and `View` lifecycle.

## Verification Results

- `dub test`: All 9 module unit tests pass.
- `dub build`: Executable builds cleanly.
