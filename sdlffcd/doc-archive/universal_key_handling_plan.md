# Universal Key Handling Plan

## Goal
Remove redundant `_UPPER` key enum variants (`SDLFFCD_KEY_Q_UPPER`, `SDLFFCD_KEY_P_UPPER`, `SDLFFCD_KEY_R_UPPER`, `SDLFFCD_KEY_F_UPPER`) in favor of universal lowercase `SDL_Keycode` handling with normalization in `sdlffcd_clib`.

## Context & Explanation
In SDL3, `SDL_EVENT_KEY_DOWN` events carry `event.key.key` (`SDL_Keycode`). Standard SDL keycodes for letter keys are lowercase ASCII (`SDLK_q` = `'q'`), regardless of Shift/Caps Lock state. By normalizing any upper-case ASCII values to lowercase in `sdlffcd_clib`'s event dispatcher, we eliminate the need for duplicate `_UPPER` key constants in the C API and D bindings.

## Steps
1. **Update C Header (`sdlffcd_clib/sdlffcd_clib.h`)**:
   - Resolve TODO comment.
   - Remove redundant `_UPPER` enum members from `sdlffcd_Key`.

2. **Update C Implementation (`sdlffcd_clib/sdlffcd_clib.c`)**:
   - Normalize ASCII uppercase keycodes to lowercase before invoking `key_callback`.

3. **Update D Bindings (`source/sdlffcd_clib.d`)**:
   - Update `sdlffcd_Key` enum and unittest to match updated C header.

4. **Refactor Event Handler (`source/app.d`)**:
   - Remove `_UPPER` case checks in `handleKeyPress`.

5. **Verification**:
   - Build `sdlffcd_clib` via ninja.
   - Run `dub test` and `dub build`.
