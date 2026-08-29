# Walkthrough: Meson Build System for D and C Components

We transitioned `sdlffcd` to use **Meson** as its primary build system for both the C bridge libraries (`sdlffcd_clib`) and the D application & tests (`sdlffcd`), while preserving `dub.json` for IDE autocompletion and language server (`serve-d`) functionality.

---

## Changes Made

### 1. Root Meson Configuration
- Created [meson.build](file:///home/yur/agy-projects/miscalg/sdlffcd/meson.build) supporting both `'c'` and `'d'` languages.
- Discovers C libraries via `subdir('sdlffcd_clib')`.
- Compiles the D application executable `sdlffcd` and test executable `sdlffcd_test` with string import paths for assets (`fonts/`).
- Registers `test('unittest', test_exe)` for test execution via `meson test`.

### 2. C Bridge Library Encapsulation
- Refactored [sdlffcd_clib/meson.build](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/meson.build):
  - Encapsulates third-party C dependencies (`sdl3`, `sdl3-ttf`, `libavutil`, `libavcodec`, `libavformat`, `libswscale`, `libswresample`, `m`).
  - Builds `sdlffcd_sdl_lib` and `sdlffcd_ffmpeg_lib`.
  - Exposes declared dependencies (`sdlffcd_sdl_dep`, `sdlffcd_ffmpeg_dep`, `sdlffcd_clib_dep`) using `declare_dependency()`.

### 3. D Source Package Organization
- Moved D sources to [source/sdlffcd/](file:///home/yur/agy-projects/miscalg/sdlffcd/source/sdlffcd) adhering to the standard D package directory convention (`module sdlffcd.<name>;` mapped to `-Isource`).

### 4. IDE & Dub Tooling Support
- Updated [dub.json](file:///home/yur/agy-projects/miscalg/sdlffcd/dub.json) to reference artifacts in `_build/sdlffcd_clib/` and trigger Meson build compilation when needed. `dub describe` and `dub test` work seamlessly.

### 5. Documentation
- Updated [README.md](file:///home/yur/agy-projects/miscalg/sdlffcd/README.md), [AGENTS.md](file:///home/yur/agy-projects/miscalg/sdlffcd/AGENTS.md), and [sdlffcd_clib/AGENTS.md](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/AGENTS.md) with Meson build/test commands and updated paths.

---

## Verification Results

### Automated Builds & Tests
1. **Meson Compilation**:
   ```bash
   export PKG_CONFIG_PATH="$HOME/.local/lib/pkgconfig:$PKG_CONFIG_PATH"
   meson setup _build
   meson compile -C _build
   ```
   *Result*: Both `sdlffcd` and `sdlffcd_test` compiled and linked successfully.

2. **Meson Test Suite**:
   ```bash
   meson test -C _build --verbose
   ```
   *Result*: All 9 D unit test modules passed (Status: `OK`).

3. **Dub Compatibility**:
   ```bash
   dub describe > /dev/null
   dub test
   ```
   *Result*: `dub describe` succeeded with exit code 0; `dub test` passed all 9 modules.

### Manual Verification
1. `./_build/sdlffcd --help` executed cleanly and printed usage information.
2. `./_build/sdlffcd samplevideo.mp4 --quit` successfully loaded the container, decoded video and audio, rendered frames, and exited cleanly upon stream completion.
