# Key Enum Constants Plan

## Goal
Replace raw magic numbers and character literals (`'Q'`, `' '`, `'p'`, `'P'`, `'r'`, `'R'`, `'f'`, `'F'`, `1073741904`, `1073741903`) in `handleKeyPress` (`source/app.d`) with clear `sdlffcd_Key` enum constants.

## Steps
1. **Extend C Header (`sdlffcd_clib/sdlffcd_clib.h`)**:
   - Add missing key constants (`SDLFFCD_KEY_SPACE`, `SDLFFCD_KEY_Q_UPPER`, `SDLFFCD_KEY_P`, `SDLFFCD_KEY_P_UPPER`, `SDLFFCD_KEY_R`, `SDLFFCD_KEY_R_UPPER`, `SDLFFCD_KEY_F`, `SDLFFCD_KEY_F_UPPER`, `SDLFFCD_KEY_LEFT`, `SDLFFCD_KEY_RIGHT`) to `sdlffcd_Key` enum.

2. **Update D Bindings (`source/sdlffcd_clib.d`)**:
   - Ensure D enum `sdlffcd_Key` matches `sdlffcd_clib.h` declarations.
   - Add unit test to verify enum values.

3. **Refactor `handleKeyPress` (`source/app.d`)**:
   - Replace literal comparisons in `handleKeyPress` with `sdlffcd_Key` enum constants.

4. **Verify**:
   - Run `dub test` and `dub build`.
