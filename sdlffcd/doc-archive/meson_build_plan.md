# Implementation Plan: Meson Build System for D and C Components

## Goal Description
Transition the project build system to **Meson** as the primary build system that compiles and links both the C bridge libraries (`sdlffcd_clib`) and the D application / tests (`sdlffcd`), while preserving `dub.json` for language server (`serve-d`) and D IDE autocompletion.

---

## User Review Required
> [!NOTE]
> - All third-party C dependencies (`sdl3`, `sdl3-ttf`, `libavutil`, `libavcodec`, `libavformat`, `libswscale`, `libswresample`, `m`) and static library targets are encapsulated inside `sdlffcd_clib/meson.build`.
> - Third-party dependencies are named naturally (e.g. `sdl3_dep`, `sdl3_ttf_dep`, `libavutil_dep`, `m_dep`), while exported project dependencies and libraries retain the `sdlffcd_` prefix (`sdlffcd_sdl_dep`, `sdlffcd_ffmpeg_dep`, `sdlffcd_clib_dep`).
> - `sdlffcd_clib/meson.build` exposes `sdlffcd_clib_dep` via `declare_dependency`, cleanly propagating libraries and link flags to the D target.
> - The D targets (`sdlffcd` and `sdlffcd_test`) in root `meson.build` depend solely on `sdlffcd_clib_dep`.
> - `dub.json` remains in place for `serve-d` / D IDE autocompletion.

---

## Proposed Changes

### C Library Build & Dependencies

#### [MODIFY] `sdlffcd_clib/meson.build`
Refactor `sdlffcd_clib/meson.build` to define third-party C dependencies, compile static bridge libraries, and export `declare_dependency` objects:

```meson
# SDL dependencies
sdl3_dep = dependency('sdl3')
sdl3_ttf_dep = dependency('sdl3-ttf')

# FFmpeg dependencies
libavutil_dep = dependency('libavutil')
libavcodec_dep = dependency('libavcodec')
libavformat_dep = dependency('libavformat')
libswscale_dep = dependency('libswscale')
libswresample_dep = dependency('libswresample')

# C compiler & math library
cc = meson.get_compiler('c')
m_dep = cc.find_library('m', required : true)

# SDL Bridge Library Target
sdl_deps = [sdl3_dep, sdl3_ttf_dep, m_dep]
sdlffcd_sdl_lib = static_library('sdlffcd_sdl',
  'sdlffcd_sdl.c',
  dependencies : sdl_deps,
)

# FFmpeg Bridge Library Target
ffmpeg_deps = [
  libavutil_dep,
  libavcodec_dep,
  libavformat_dep,
  libswscale_dep,
  libswresample_dep,
  m_dep,
]
sdlffcd_ffmpeg_lib = static_library('sdlffcd_ffmpeg',
  'sdlffcd_ffmpeg.c',
  dependencies : ffmpeg_deps,
)

# Dependency Objects for Root Project Consumption
sdlffcd_sdl_dep = declare_dependency(
  link_with : sdlffcd_sdl_lib,
  dependencies : sdl_deps,
  include_directories : include_directories('.'),
)

sdlffcd_ffmpeg_dep = declare_dependency(
  link_with : sdlffcd_ffmpeg_lib,
  dependencies : ffmpeg_deps,
  include_directories : include_directories('.'),
)

sdlffcd_clib_dep = [sdlffcd_sdl_dep, sdlffcd_ffmpeg_dep]
```

---

### Root Build Configuration

#### [NEW] `meson.build` (Root)
Create the root Meson build configuration:
- Declare project `sdlffcd` with `['c', 'd']` languages, C standard `c99`, and warnings enabled.
- Include `subdir('sdlffcd_clib')` to build C libraries and obtain `sdlffcd_clib_dep`.
- Define D source list from `source/*.d`.
- Specify string import directories (`d_import_dirs: [include_directories('.')]`) for `import("fonts/GoogleSansCode-Regular.ttf")`.
- Build the main executable `sdlffcd` with `dependencies: sdlffcd_clib_dep`.
- Build the test executable `sdlffcd_test` with `d_unittest: true` and `dependencies: sdlffcd_clib_dep`, and register test runner `test('unittest', test_exe)`.

```meson
project('sdlffcd', ['c', 'd'],
  version : '0.1.0',
  default_options : [
    'warning_level=everything',
    'c_std=c99',
  ],
  meson_version: '>=1.7.0'
)

# C bridge libraries and their dependencies
subdir('sdlffcd_clib')

# D Source Files
d_sources = files(
  'source/app.d',
  'source/app_context.d',
  'source/frame_ring_buffer.d',
  'source/models.d',
  'source/observable.d',
  'source/player_controller.d',
  'source/player_view.d',
  'source/sdl_logger.d',
  'source/sdlffcd_clib.d',
  'source/sdlffcd_ffmpeg.d',
  'source/sdlffcd_sdl.d',
  'source/video_player.d',
)

# String import directory for assets (fonts, etc.)
d_import_dirs = include_directories('.')

# Main Executable
executable('sdlffcd',
  d_sources,
  d_import_dirs : [d_import_dirs],
  dependencies : sdlffcd_clib_dep,
  install : true,
)

# Test Executable
test_exe = executable('sdlffcd_test',
  d_sources,
  d_unittest : true,
  d_import_dirs : [d_import_dirs],
  dependencies : sdlffcd_clib_dep,
)

test('unittest', test_exe)
```

---

### IDE & Tooling Support

#### [MODIFY] `dub.json`
- Preserve `dub.json` so `serve-d` / IDEs can resolve AST and imports.

---

### Documentation

#### [MODIFY] `README.md` & `AGENTS.md`
- Update build and test commands to showcase Meson:
  ```bash
  export PKG_CONFIG_PATH="$HOME/.local/lib/pkgconfig:$PKG_CONFIG_PATH"
  meson setup _build
  meson compile -C _build
  meson test -C _build
  ./_build/sdlffcd samplevideo.mp4
  ```
- Note that `dub.json` is maintained for `serve-d` / IDE autocompletion.

---

## Verification Plan

### Automated Tests
1. **Meson Setup & Build**:
   ```bash
   export PKG_CONFIG_PATH="$HOME/.local/lib/pkgconfig:$PKG_CONFIG_PATH"
   meson setup _build
   meson compile -C _build
   ```
2. **Meson Test Suite**:
   ```bash
   meson test -C _build --verbose
   ```
3. **Dub compatibility check** (for `serve-d` / IDEs):
   ```bash
   dub describe > /dev/null
   ```

### Manual Verification
1. Run `./_build/sdlffcd --help` and verify help text displays properly.
2. Run `./_build/sdlffcd samplevideo.mp4 --quit` or interactive test to ensure rendering and playback succeed without issue.
