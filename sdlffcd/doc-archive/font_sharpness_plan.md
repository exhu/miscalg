# Font Sharpness Optimization Plan

## Goal Description
The text overlay (timestamp and IN/OUT markers) currently rendered via `SDL3_ttf` text engine can appear unsharp or blurry. This plan explains why FreeType/SDL3_ttf rendering might look blurry, explores the available SDL3_ttf options and FreeType rendering flags, and proposes concrete changes to allow configuring font hinting, handling display scaling/DPI, and snapping draw coordinates to exact pixel boundaries.

---

## Technical Analysis: Why Fonts May Look Blurry in SDL3_ttf & FreeType

Font rendering softness in `SDL3_ttf` (using `TTF_CreateRendererTextEngine`) typically stems from four main factors:

1. **FreeType Hinting Setting (`TTF_HintingFlags`)**:
   - `TTF_OpenFont` defaults to `TTF_HINTING_NORMAL`. For modern outline fonts (like `GoogleSansCode-Regular.ttf`), `NORMAL` grid-fitting can sometimes distort stem widths or blur anti-aliasing edges at small sizes.
   - `TTF_HINTING_LIGHT_SUBPIXEL` enables FreeType's subpixel-aware light hinter (`FT_LOAD_TARGET_LCD`), which preserves font geometry while sharpening vertical stems.
   - `TTF_HINTING_LIGHT` uses horizontal-only auto-hinting, keeping curves smooth and natural.
   - `TTF_HINTING_MONO` snaps all edges strictly to the pixel grid (1-bit rasterization), creating razor-sharp pixel edges with no intermediate gray smoothing.
   - `TTF_HINTING_NONE` turns off grid-fitting completely, rendering purely anti-aliased vector outlines.

2. **Display Scale & DPI (High-DPI / Retina / Fractional Scaling)**:
   - On displays with display scaling (> 1.0x, such as 125%, 150%, or 200%), SDL3 creates a window with high pixel density.
   - If the font is opened at `19pt` in logical point space without accounting for `SDL_GetWindowDisplayScale(window)` or `TTF_SetFontSizeDPI()`, the glyph atlas is rasterized at low resolution (19px) and then upscaled by the GPU renderer to physical pixels using bilinear interpolation, leading to noticeable blurring.

3. **Subpixel Floating-Point Coordinate Sampling**:
   - In `player_view.d`, text positions are computed as floats (e.g., `windowW - tsW - margin`).
   - If rendered at non-integer pixel positions (e.g. `x = 642.5`), texture filtering blurs font edges across neighboring screen pixels. Rounding/snapping coordinates (`floorf` / `roundf`) ensures 1:1 texel-to-pixel mapping.

4. **SDF (Signed Distance Fields)**:
   - SDL3_ttf supports `TTF_SetFontSDF()`. SDF is intended for dynamic scaling and 3D transforms, but for static 2D UI text at 1:1 scale, SDF reduces sharpness compared to direct rasterization. (We keep SDF off).

---

## User Review Required

> [!IMPORTANT]
> We can expose a font hinting configuration in `sdlffcd_clib` and test the difference between `TTF_HINTING_LIGHT_SUBPIXEL`, `TTF_HINTING_LIGHT`, `TTF_HINTING_NORMAL`, and `TTF_HINTING_MONO`, while also ensuring display DPI scaling and pixel coordinate snapping are applied.

---

## Proposed Changes

### Component 1: `sdlffcd_clib` (C Library)

#### [MODIFY] `sdlffcd_clib/sdlffcd_clib.h`
- Define `sdlffcd_FontHinting` enum mirroring `TTF_HintingFlags`:
  - `SDLFFCD_FONT_HINTING_NORMAL = 0`
  - `SDLFFCD_FONT_HINTING_LIGHT = 1`
  - `SDLFFCD_FONT_HINTING_MONO = 2`
  - `SDLFFCD_FONT_HINTING_NONE = 3`
  - `SDLFFCD_FONT_HINTING_LIGHT_SUBPIXEL = 4`
- Add API function declarations:
  - `bool sdlffcd_font_set_hinting(sdlffcd_Font* font, sdlffcd_FontHinting hinting);`
  - `sdlffcd_FontHinting sdlffcd_font_get_hinting(const sdlffcd_Font* font);`
  - `float sdlffcd_app_get_display_scale(const sdlffcd_AppContext* app);`
  - `bool sdlffcd_font_set_size_dpi(sdlffcd_Font* font, float ptsize, int hdpi, int vdpi);`

#### [MODIFY] `sdlffcd_clib/sdlffcd_clib.c`
- Implement `sdlffcd_font_set_hinting` calling `TTF_SetFontHinting`.
- Implement `sdlffcd_font_get_hinting` calling `TTF_GetFontHinting`.
- Implement `sdlffcd_app_get_display_scale` calling `SDL_GetWindowDisplayScale(app->window)`.
- Implement `sdlffcd_font_set_size_dpi` calling `TTF_SetFontSizeDPI`.

---

### Component 2: D Bindings & App Logic

#### [MODIFY] `source/sdlffcd_clib.d`
- Mirror enum `sdlffcd_FontHinting` and new C API functions in 1-to-1 sync.
- Add unit tests for the new functions.

#### [MODIFY] `source/player_view.d`
- Set hinting to `SDLFFCD_FONT_HINTING_NORMAL`.
- Snap text draw coordinates `tsX`, `tsY`, `ioX`, `ioY` to integer pixels using `std.math.floor` or integer truncation to eliminate bilinear subpixel blur.

---

## Verification Plan

### Automated Tests
- Run `dub test` to ensure C and D bindings, unit tests, and regression tests pass cleanly.

### Manual Verification
- Run `./sdlffcd samplevideo.mp4`.
- Inspect the timestamp overlay in all 4 screen positions to verify crisp text edges.
- Compare sharpness across hinting modes (`LIGHT_SUBPIXEL`, `LIGHT`, `NORMAL`, `MONO`).
