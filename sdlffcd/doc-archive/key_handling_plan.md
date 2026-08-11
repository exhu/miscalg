# Implementation Plan - Key Handling in D Code

Move 'Q' and 'ESCAPE' key event handling from `sdlffcd_clib/sdlffcd_clib.c` to `source/app.d`. `sdlffcd_clib` will expose a key callback registration interface, key code enums, and non-blocking event polling so that D code handles application shutdown on key presses.

## User Review Required

> [!IMPORTANT]
> - `sdlffcd_clib.c` will no longer hardcode application exit on `SDLK_Q` or `SDLK_ESCAPE`.
> - Key handling logic is migrated completely to D (`source/app.d`), delegating key press decisions to D code via a C-compatible callback mechanism (`sdlffcd_KeyCallback`).
> - Non-blocking event polling (`sdlffcd_app_poll_events`) will be called during video playback so key events are processed seamlessly without freezing video rendering.

## Open Questions

None. The requirements are clear and align with the existing architecture.

## Proposed Changes

### `sdlffcd` C Library Component

#### [MODIFY] [sdlffcd_clib.h](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.h)
- Define `sdlffcd_Key` enum (including `SDLFFCD_KEY_ESCAPE = 27` and `SDLFFCD_KEY_Q = 'q'`).
- Define `sdlffcd_KeyCallback` function pointer type (`void (*)(void* userdata, uint32_t key)`).
- Declare `sdlffcd_app_stop(sdlffcd_AppContext* app)`.
- Declare `sdlffcd_app_set_key_callback(sdlffcd_AppContext* app, sdlffcd_KeyCallback cb, void* userdata)`.
- Declare `sdlffcd_app_poll_events(sdlffcd_AppContext* app)`.

#### [MODIFY] [sdlffcd_clib_private.h](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib_private.h)
- Add `key_callback` and `key_callback_userdata` fields to `sdlffcd_AppContext` struct.

#### [MODIFY] [sdlffcd_clib.c](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.c)
- Implement `sdlffcd_app_stop`, `sdlffcd_app_set_key_callback`, and `sdlffcd_app_poll_events`.
- Refactor event handling helper `process_single_event` to invoke `app->key_callback` on `SDL_EVENT_KEY_DOWN`.
- Remove hardcoded `SDLK_ESCAPE` and `SDLK_Q` checks from `sdlffcd_clib.c`.

---

### `source` D Component

#### [MODIFY] [sdlffcd_clib.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/sdlffcd_clib.d)
- Declare `sdlffcd_Key` enum matching `sdlffcd_clib.h`.
- Declare `sdlffcd_KeyCallback` alias matching `sdlffcd_clib.h`.
- Declare `sdlffcd_app_stop`, `sdlffcd_app_set_key_callback`, and `sdlffcd_app_poll_events` C externs.

#### [MODIFY] [app.d](file:///home/yur/agy-projects/miscalg/sdlffcd/source/app.d)
- Implement `handleKeyPress` callback checking for `SDLFFCD_KEY_ESCAPE`, `SDLFFCD_KEY_Q`, or `'Q'` and invoking `sdlffcd_app_stop`.
- Register `handleKeyPress` with `sdlffcd_app_set_key_callback` in `main`.
- Add `sdlffcd_app_poll_events(app)` call inside the `decode_video_file` loop to handle key presses while playing video.

---

## Verification Plan

### Automated Tests
- Run `dub build` to verify compilation of C library and D application.

### Manual Verification
- Run `./sdlffcd samplevideo.mp4` and verify video decoding and playback start cleanly.
- Verify key presses in D application (or simulate via wake events / test execution).
