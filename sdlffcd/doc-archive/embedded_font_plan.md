# Embedded Font Loading Plan

## Goal Description
Update `sdlffcd_font_open` in `sdlffcd_clib` (C library) and `source/sdlffcd_sdl.d` (D bindings) to accept font data from memory buffer (`const void* data, size_t data_size`) instead of a file path, and update `source/player_view.d`'s `initialize` method to pass `regularFontData` embedded binary font data to `sdlffcd_font_open`.

---

## Technical Details

1. **C Library Bridge (`sdlffcd_clib/sdlffcd_sdl.h`, `sdlffcd_clib/sdlffcd_sdl.c`)**:
   - Change `sdlffcd_font_open(const char* filepath, float ptsize)` to `sdlffcd_font_open(const void* data, size_t data_size, float ptsize)`.
   - In implementation:
     - Validate `data != NULL`, `data_size > 0`, and `ptsize > 0.0f`.
     - Create `SDL_IOStream` via `SDL_IOFromConstMem(data, data_size)`.
     - Call `TTF_OpenFontIO(io, true, ptsize)` (`closeio = true` ensures the IO stream is closed when the font is closed or on open failure).
     - Allocate and return `sdlffcd_Font*`.

2. **D Binding (`source/sdlffcd_sdl.d`)**:
   - Update function signature to `sdlffcd_Font* sdlffcd_font_open(const(void)* data, size_t data_size, float ptsize);` maintaining 1-to-1 parity with C header.
   - Update unittest in `source/sdlffcd_sdl.d` to call `sdlffcd_font_open(null, 0, 12.0f)`.

3. **Player View (`source/player_view.d`)**:
   - In `View.initialize`, replace `sdlffcd_font_open(toStringz(""), 19.0f)` with `sdlffcd_font_open(regularFontData.ptr, regularFontData.length, 19.0f)`.

---

## Verification Plan

1. **Unit Tests**:
   - Run `dub test` to ensure C library compiles, bindings match, and test suite passes.
2. **Build**:
   - Run `dub build` to ensure binary builds without errors.
