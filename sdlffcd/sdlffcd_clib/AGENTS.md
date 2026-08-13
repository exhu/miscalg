# Agent Guidelines for sdlffcd_clib

`sdlffcd_clib` is a C99 library bridging third-party C libraries (SDL3, SDL3_ttf, FFmpeg) for consumption by the D `sdlffcd` application.

---

## Environment & Build Rules

- **PKG_CONFIG_PATH**: Always prepend `~/.local/lib/pkgconfig` to `PKG_CONFIG_PATH` before invoking `meson setup` or configuration commands.
  ```bash
  export PKG_CONFIG_PATH="$HOME/.local/lib/pkgconfig:$PKG_CONFIG_PATH"
  ```
- **Build Directory**: Use the `_build` subdirectory for Meson builds (`sdlffcd_clib/_build`).

---

## API & Architecture Rules

- **Symbol Prefix**: All public functions, structs, types, and enum constants must be prefixed with `sdlffcd_` or `SDLFFCD_`.
- **Public vs. Private Headers**:
  - `sdlffcd_clib.h`: Public API declarations and opaque struct definitions. Must be kept in 1-to-1 sync with `source/sdlffcd_clib.d`.
  - `sdlffcd_clib_private.h`: Internal header containing real struct definitions and private C includes.
