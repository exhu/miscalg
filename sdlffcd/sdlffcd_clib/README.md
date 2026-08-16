`sdlffcd_clib` contains C99 bridge libraries that help avoid writing and keeping up to date full-featured bindings to C dependencies for D application consumption:
- `sdlffcd_sdl` (`libsdlffcd_sdl.a`): SDL3 window, event loop, renderer, audio playback stream, font/text rendering (SDL3_ttf), and logging.
- `sdlffcd_ffmpeg` (`libsdlffcd_ffmpeg.a`): FFmpeg container demuxing, video decoding, audio decoding, resampling, and seeking.

Public D API externals (opaque structs) go into `sdlffcd_sdl.h` and `sdlffcd_ffmpeg.h`, private APIs (real structs) into `sdlffcd_sdl_private.h` and `sdlffcd_ffmpeg_private.h`.

All public symbols are prefixed with `sdlffcd_` or `SDLFFCD_`.
