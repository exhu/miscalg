# Agent Guidelines for sdlffcd_clib

`sdlffcd_clib` contains decoupled C99 bridge libraries bridging third-party C libraries (SDL3, SDL3_ttf, FFmpeg) for consumption by the D `sdlffcd` application:
- `sdlffcd_sdl`: SDL3 & SDL3_ttf bridge library (`libsdlffcd_sdl.a`).
- `sdlffcd_ffmpeg`: FFmpeg audio/video demuxing & decoding bridge library (`libsdlffcd_ffmpeg.a`).

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
  - `sdlffcd_sdl.h`: Public SDL API declarations and opaque struct definitions. Kept in 1-to-1 sync with `source/sdlffcd_sdl.d`.
  - `sdlffcd_sdl_private.h`: Internal header containing real SDL struct definitions.
  - `sdlffcd_ffmpeg.h`: Public FFmpeg API declarations and opaque struct definitions. Kept in 1-to-1 sync with `source/sdlffcd_ffmpeg.d`.
  - `sdlffcd_ffmpeg_private.h`: Internal header containing real FFmpeg struct definitions.
