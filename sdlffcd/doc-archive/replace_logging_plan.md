# Implementation Plan: Replace Diagnostic Logging with SDL Logging

Migrate all diagnostic console output (`writeln`, `writefln`, `stderr.writeln`, `stderr.writefln`) across D modules to `std.logger` backed by [`SdlLogger`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/sdl_logger.d), and migrate all C error logging (`fprintf(stderr, ...)`) in `sdlffcd_clib` to `SDL_LogError`.

## Goal Description

Currently, the codebase uses ad-hoc `writeln`, `writefln`, `stderr.writeln`, and `fprintf` calls scattered across multiple files for diagnostic logging (initialization, playback status, seek events, errors). This creates inconsistent log output and bypasses SDL3's built-in logging framework and log priority filtering.

We will:
1. Initialize `sharedLog` with [`SdlLogger`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/sdl_logger.d) in [`source/app.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/app.d).
2. Replace all diagnostic `writeln`/`writefln`/`stderr` logging with `info`/`infof`/`error`/`errorf` in D modules (`app.d`, `app_context.d`, `video_player.d`, `player_controller.d`, `player_view.d`).
3. Retain pure user-facing stdout outputs where appropriate (e.g. CLI `--help` text in `printHelp()` and FFmpeg cut command string output in `printFfmpegCutCommand()`).
4. Replace all `fprintf(stderr, ...)` calls in [`sdlffcd_clib/sdlffcd_clib.c`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.c) with `SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, ...)`.

---

## User Review Required

> [!NOTE]
> - CLI help message (`printHelp()`) and FFmpeg cut command output (`printFfmpegCutCommand()`) remain standard stdout `writeln` calls as they are user-facing CLI output intended for shell redirection / copy-paste, rather than diagnostic logs. All runtime diagnostics (opening files, media info, seeking, pause/resume, errors) will go through `std.logger` / `SdlLogger`.
> - If you want the FFmpeg cut command or help message redirected to SDL logging as well, please let us know.

---

## Proposed Changes

### C Library: `sdlffcd_clib`

#### [MODIFY] [sdlffcd_clib/sdlffcd_clib.c](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.c)
- Replace all 9 `fprintf(stderr, ...)` error messages with `SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, ...)`:
  - `SDL_Init` failure
  - `SDL_CreateWindow` failure
  - `SDL_CreateRenderer` failure
  - `TTF_Init` failure
  - `TTF_CreateRendererTextEngine` failure
  - `SDL_RegisterEvents` failure
  - Video texture creation failure
  - `TTF_OpenFont` failure
  - `TTF_CreateText` failure

---

### D Application: `source/`

#### [MODIFY] [source/sdl_logger.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/sdl_logger.d)
- Provide default argument `LogLevel.all` in constructor `this(LogLevel lv = LogLevel.all, int sdlCategory = 0)`.
- Ensure clean integration with `std.logger`.

#### [MODIFY] [source/app.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/app.d)
- Import `std.logger` and `sdlffcd.sdl_logger`.
- Configure `sharedLog = cast(shared) new SdlLogger(LogLevel.info);` at startup of `main()`.
- Replace diagnostic messages:
  - `stderr.writefln("Unknown option: %s\n", arg)` -> `errorf("Unknown option: %s", arg)`
  - `stderr.writeln("Failed to initialize player controller resources.")` -> `error("Failed to initialize player controller resources.")`
  - `stderr.writeln("Failed to open video file: ", filename)` -> `errorf("Failed to open video file: %s", filename)`
  - `writeln("\nStarting main event loop...")` -> `info("Starting main event loop...")`
  - `writeln("Exited cleanly.")` -> `info("Exited cleanly.")`

#### [MODIFY] [source/app_context.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/app_context.d)
- Replace:
  - `writeln("Initializing SDL application...")` -> `info("Initializing SDL application...")`
  - `stderr.writeln("Failed to initialize application context.")` -> `error("Failed to initialize application context.")`

#### [MODIFY] [source/video_player.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/video_player.d)
- Replace:
  - `writeln("VideoPlayer: Opening video file: ", filename)` -> `infof("VideoPlayer: Opening video file: %s", filename)`
  - `stderr.writeln("VideoPlayer: Failed to open video file: ", filename)` -> `errorf("VideoPlayer: Failed to open video file: %s", filename)`
  - `writefln("Container format: %s", ...)` -> `infof("Container format: %s", ...)`
  - `writefln("Video codec: %s", ...)` -> `infof("Video codec: %s", ...)`
  - `writefln("Audio codec: %s", ...)` -> `infof("Audio codec: %s", ...)`
  - `writefln("Resolution: %dx%d", ...)` -> `infof("Resolution: %dx%d", ...)`
  - `writefln("Duration: %.2f sec, FPS: %.2f, Frames: %d", ...)` -> `infof("Duration: %.2f sec, FPS: %.2f, Frames: %d", ...)`
  - `writeln("VideoPlayer: Reached end of video stream.")` -> `info("VideoPlayer: Reached end of video stream.")`
  - `stderr.writeln("VideoPlayer: Error decoding frame.")` -> `error("VideoPlayer: Error decoding frame.")`
  - `writefln("VideoPlayer: Paused at %.2f s", currentPts)` -> `infof("VideoPlayer: Paused at %.2f s", currentPts)`
  - `writefln("VideoPlayer: Resumed at %.2f s", currentPts)` -> `infof("VideoPlayer: Resumed at %.2f s", currentPts)`
  - `writefln("VideoPlayer: Seeking to %.2f seconds", targetPts)` -> `infof("VideoPlayer: Seeking to %.2f seconds", targetPts)`

#### [MODIFY] [source/player_controller.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/player_controller.d)
- Replace:
  - `writeln("Key press received in D (Q / ESCAPE). Requesting app stop...")` -> `info("Key press received in D (Q / ESCAPE). Requesting app stop...")`
  - `writefln("IN-marker set to %.3f s (OUT: %.3f s)", ...)` -> `infof("IN-marker set to %.3f s (OUT: %.3f s)", ...)`
  - `writefln("OUT-marker set to %.3f s (IN: %.3f s)", ...)` -> `infof("OUT-marker set to %.3f s (IN: %.3f s)", ...)`
  - `writefln("Loop mode: %s", ...)` -> `infof("Loop mode: %s", ...)`
  - `writeln("Playback finished (end of video stream). Quitting...")` -> `info("Playback finished (end of video stream). Quitting...")`
  - `stderr.writeln("Playback stopped due to error.")` -> `error("Playback stopped due to error.")`

#### [MODIFY] [source/player_view.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/player_view.d)
- Replace:
  - `stderr.writeln("Failed to create timestamp text object.")` -> `error("Failed to create timestamp text object.")`
  - `stderr.writeln("Failed to create in-out text object.")` -> `error("Failed to create in-out text object.")`
  - `stderr.writefln("Failed to open font %s", fontPath)` -> `errorf("Failed to open font %s", fontPath)`

---

## Verification Plan

### Automated Tests
1. Run all unit tests:
   ```bash
   dub test
   ```
2. Build executable:
   ```bash
   dub build
   ```

### Manual Verification
1. Run application with sample video:
   ```bash
   ./sdlffcd samplevideo.mp4
   ```
2. Verify that SDL log outputs are properly tagged and formatted on the console during launch, playback, pause/resume, seeking, and exit.
3. Test `--help` to confirm CLI help text is cleanly printed.
