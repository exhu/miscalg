# Code Review & Refactoring Recommendations for `sdlffc`

## Summary of Findings

`sdlffc` is an SDL3 + FFmpeg media player library/application written in C99. This document outlines key areas of improvement, bug fixes, and refactoring recommendations identified during the code review.

---

## 1. Concurrency & Thread Synchronization (`mailbox.c`, `mailbox.h`, `sdlffclib.c`, `sdlffclib_private.h`)

### Flaws & Bugs:
- **Incorrect Mailbox Buffer Initialization**:
  In `sdlffclib_init()` ([sdlffclib.c](file:///home/yur/agy-projects/miscalg/sdlffc/sdlffclib.c#L167-L170)):
  ```c
  mailbox_init(&context->video_thread_mailbox,
               &context->video_thread_mailbox_data,
               sizeof(context->main_thread_mailbox_data)); // BUG: should be video_thread_mailbox_data
  ```
- **Spurious Wakeup Handling**:
  `mailbox_receive_and_lock()` in [mailbox.c](file:///home/yur/agy-projects/miscalg/sdlffc/mailbox.c#L41-L47) checks condition variables directly without checking `mb->is_set` in a loop, which can lead to missed signals or unhandled spurious wakeups.
- **Thread Shutdown Sequence**:
  In `sdlffclib_done()`, `VTC_QUIT` signal is sent to `video_thread_mailbox`, but if the thread is blocked waiting on condition, the wakeup condition signaling must ensure mutex locking alignment.

### Recommendations:
- Fix mailbox buffer size argument in `sdlffclib_init()`.
- Refactor `mailbox_receive_and_lock()` to properly loop on predicate `!mb->is_set`.
- Ensure clean shutdown synchronization between the main UI thread and video decoding thread.

---

## 2. Resource Management & Memory Safety (`sdlffclib.c`)

### Flaws & Bugs:
- **Static Context Singleton**:
  `sdlffclib_init()` uses a static `global_context` instance. If `sdlffclib_done()` is called and `sdlffclib_init()` is invoked again, stale context states may cause memory corruption or unexpected runtime behavior.
- **Incomplete Cleanup Guard**:
  In `sdlffclib_free_video_file_ctx()` ([sdlffclib.c](file:///home/yur/agy-projects/miscalg/sdlffc/sdlffclib.c#L182-L195)):
  ```c
  if (ctx->ic) {
    if (ctx->frame) av_frame_free(&ctx->frame);
    if (ctx->pkt) av_packet_free(&ctx->pkt);
    // ...
  }
  ```
  If `avformat_open_input` fails or `ctx->ic` is `NULL`, but `pkt` or `frame` were allocated before failure, they will leak.

### Recommendations:
- Change context allocation to dynamic allocation using `SDL_calloc()` and `SDL_free()`.
- Guard each resource pointer independently inside `sdlffclib_free_video_file_ctx()`.

---

## 3. Code Cleanliness & Warning Elimination (`sdlffclib.c`, `meson.build`)

### Flaws & Bugs:
- **Format Specifier Mismatches**:
  In `sdlffclib_fileinfo()` ([sdlffclib.c](file:///home/yur/agy-projects/miscalg/sdlffc/sdlffclib.c#L846-L848)), `%d` is passed for `unsigned int` `ic->nb_streams` and loop variable `i`, generating compiler warnings under `-Wwarning_level=everything`.
- **Dead / Unused Functions & Variables**:
  - Unused static functions: `timer_cb`, `process_next_file_frame`, `get_supported_pixel_format_cb`.
  - Unused variables: `cursor`, `area`, `i`, `config`, `pts`.
- **Switch Enum Exhaustiveness Warnings**:
  `get_texture_for_memory_frame()` has a `switch (frame_format)` statement missing explicit cases for unhandled SDL pixel format enum variants.

### Recommendations:
- Replace `%d` with `%u` for unsigned log outputs.
- Remove dead code or integrate required functions into active execution paths.
- Add `default:` branches or targeted `#pragma` directives where appropriate for switch warnings.

---

## 4. Architectural Enhancements

- **Frame Decoding Queue Architecture**:
  Complete the pipeline where `video_thread` demuxes/decodes frames into a thread-safe ring buffer / queue, allowing `main_thread` to render frames aligned with SDL timers/VSync.
- **Error Handling**:
  Provide descriptive error reporting routines via `SDL_SetError` when FFmpeg API calls return negative error codes.
