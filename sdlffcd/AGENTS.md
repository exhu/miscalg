# Agent Guidelines for sdlffcd

`sdlffcd` is a standalone D application (video player with video editing/trimming features) that uses the custom `sdlffcd_clib` C libraries (`sdlffcd_sdl` and `sdlffcd_ffmpeg`) to bridge calls to third-party C dependencies (SDL3, SDL3_ttf, FFmpeg).

See also: @sdlffcd_clib/AGENTS.md

---

## Key Rules & Guidelines

- **C Dependencies**: All third-party C library functionality (SDL3, FFmpeg, SDL3_ttf) must be accessed via `sdlffcd_clib` bridge libraries. See @sdlffcd_clib/README.md.
- **D/C Header Synchronization**: `source/sdlffcd/sdlffcd_sdl.d` and `source/sdlffcd/sdlffcd_ffmpeg.d` **must** contain D declarations that match `sdlffcd_clib/sdlffcd_sdl.h` and `sdlffcd_clib/sdlffcd_ffmpeg.h` 1-to-1.
- **Conversation Artifacts**: Store all conversation artifacts (such as plans and walkthroughs) in the `doc-archive/` directory using descriptive names (e.g. `<feature>_plan.md` and `<feature>_walkthrough.md`). In case of name conflicts, pick a unique descriptive name.
- **Playback Testing**: Use `samplevideo.mp4` for manual testing and video playback verification.

---

## Build & Test Commands

- **Setup Build Directory**:
  ```bash
  export PKG_CONFIG_PATH="$HOME/.local/lib/pkgconfig:$PKG_CONFIG_PATH"
  meson setup _build
  ```
- **Build Executable**: `meson compile -C _build`
- **Run Unit Tests**: `meson test -C _build` (or `dub test`)
- **Run Application**: `./_build/sdlffcd samplevideo.mp4`
