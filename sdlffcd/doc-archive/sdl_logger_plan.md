# SDL_Log API Bindings & SdlLogger Implementation Plan

Plan for making SDL3 Log API available to D via `sdlffcd_clib` and implementing custom D Logger (`SdlLogger`).

## Summary of Design
1. **C Library Layer (`sdlffcd_clib`)**:
   - `sdlffcd_LogPriority` enum mirroring `SDL_LogPriority`.
   - `sdlffcd_log_message(int category, sdlffcd_LogPriority priority, const char* message)` wrapping variadic `SDL_LogMessage`.
   - `sdlffcd_log_set_all_priority(sdlffcd_LogPriority priority)` wrapping `SDL_SetLogPriorities`.
2. **D Binding Layer (`sdlffcd_clib.d`)**:
   - 1-to-1 matching C declarations under `extern(C)`.
   - Unittests validating priority enum values and null handling.
3. **D Custom Logger (`sdl_logger.d`)**:
   - `class SdlLogger : Logger` deriving from `std.logger.core.Logger`.
   - Implements `writeLogMsg(ref LogEntry payload) @safe`.
   - Maps `LogLevel` to `sdlffcd_LogPriority`.
   - Unit tests covering mapping and message routing.
