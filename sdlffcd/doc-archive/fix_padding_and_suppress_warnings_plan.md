# Plan: Suppress SDL Header Warnings and Fix Structure Padding

## Objectives
1. **Suppress SDL Header Warnings**: Surround the inclusion of `<SDL3/SDL.h>` in `sdlffcd_clib_private.h` with compiler pragmas (`#pragma GCC diagnostic push`, `#pragma GCC diagnostic ignored "-Wpadded"`, `#pragma GCC diagnostic pop`) so that third-party SDL headers do not trigger `-Wpadded` warnings under strict compilation options (`warning_level=everything`).
2. **Fix Structure Padding Warnings**: Reorder struct members and add explicit alignment padding to structures defined in `sdlffcd_clib`:
   - `sdlffcd_MediaInfo` (in `sdlffcd_clib.h` and `source/sdlffcd_clib.d`)
   - `sdlffcd_VideoFrame` (in `sdlffcd_clib.h` and `source/sdlffcd_clib.d`)
   - `struct sdlffcd_AppContext` (in `sdlffcd_clib_private.h`)
   - `struct sdlffcd_VideoContext` (in `sdlffcd_clib_private.h`)
3. **Keep D Declarations Synchronized**: Ensure `source/sdlffcd_clib.d` field declarations match `sdlffcd_clib.h`.
4. **Verification**: Compile `sdlffcd_clib` with `ninja` (warning level = everything) and run `dub test` / `dub build`.

## Implementation Details
- `sdlffcd_clib_private.h`: Added diagnostic pragmas around `#include <SDL3/SDL.h>` and reordered/padded `sdlffcd_AppContext` fields (`uint32_t wake_event_type`, `bool running`, `uint8_t _pad[3]`).
- `sdlffcd_clib.h`: Reordered `sdlffcd_MediaInfo` fields to align 8-byte, 4-byte, and char arrays cleanly. Reordered `sdlffcd_VideoFrame` fields (`uint8_t* data[8]`, `double pts`, `int linesize[8]`, `int width`, `int height`, `int pixel_format`, `uint8_t _pad[4]`). Declared missing prototype for `sdlffcd_video_decode_frame`.
- `source/sdlffcd_clib.d`: Updated D bindings to mirror `sdlffcd_MediaInfo` and `sdlffcd_VideoFrame`.
