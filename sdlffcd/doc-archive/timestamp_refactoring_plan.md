# Refactoring Plan: Move Player Timestamp Rendering and Lifetime to PlayerController and Models

## Goal Description
Currently, `AppContext` (`source/app_context.d`) manages the lifetime of rendering resources (`timestampFont` and `timestampText`) and performs direct rendering via `renderTimestamp()`. 

The goal of this refactoring is to decouple UI timestamp rendering and resource lifetime management from `AppContext` and move them into `PlayerController` (`source/player_controller.d`), `View` (`source/player_view.d`), and model formatting utilities (`source/models.d`). 

After this change:
- `AppContext` is simplified and strictly responsible for application window/context management and wrapping `VideoPlayer`.
- `View` owns the `timestampFont` and `timestampText` resources and performs rendering based on `ViewModel` parameters (including timestamp text and `TimePosition`).
- `PlayerController` manages the `View` lifetime, updates `PlayerModel` and `ViewModel` state during playback updates and keypresses (such as cycling `TimePosition` with key `T`), and invokes `View.render`.
- `models.d` houses the `Hms1000` timestamp formatting logic and unittests.

---

## User Review Required

> [!IMPORTANT]
> **Key Bindings**: Adding key `'T'` / `SDLFFCD_KEY_T` to cycle timestamp rendering position (`topLeft` -> `topRight` -> `bottomRight` -> `bottomLeft` -> `invisible`).

> [!NOTE]
> **View Resource Initialization**: `PlayerController.initialize()` will initialize `View` resources using `appContext.app`, and `PlayerController.destroy()` will free font and text objects on shutdown.

---

## Open Questions

None at this time. Requirements align cleanly with the architecture of `sdlffcd`.

---

## Proposed Changes

### Core Models (`source/models.d`)

#### [MODIFY] `source/models.d`
- Move `Hms1000` struct and `formatTimestamp` function into `models.d`.
- Include unittests for `formatTimestamp`.

```d
struct Hms1000
{
    long hours, minutes, seconds;
    int mSeconds;

    void fromSeconds(double dsec)
    {
        long sec = cast(long) dsec;
        mSeconds = cast(int)((dsec - sec) * 1000.0);
        if (mSeconds < 0) mSeconds = 0;
        if (mSeconds > 999) mSeconds = 999;
        hours = sec / 3600;
        minutes = (sec % 3600) / 60;
        seconds = sec % 60;
    }
}

string formatTimestamp(double posSec, double totalSec)
{
    if (posSec < 0.0) posSec = 0.0;
    if (totalSec < 0.0) totalSec = 0.0;

    Hms1000 current, total;
    current.fromSeconds(posSec);
    total.fromSeconds(totalSec);

    return format("%02d:%02d:%02d.%03d / %02d:%02d:%02d.%03d",
        current.hours, current.minutes, current.seconds, current.mSeconds,
        total.hours, total.minutes, total.seconds, total.mSeconds);
}
```

---

### Player View (`source/player_view.d`)

#### [MODIFY] `source/player_view.d`
- Add `timestampFont` (`sdlffcd_Font*`) and `timestampText` (`sdlffcd_Text*`) to `struct View`.
- Add `initialize(sdlffcd_AppContext* app)` to open font `fonts/GoogleSansCode-Regular.ttf` and create `timestampText`.
- Add `destroy()` to safely close `timestampText` and `timestampFont`.
- Implement `render(sdlffcd_AppContext* app, ref const(ViewModel) viewModel)`:
  - If `viewModel.timePosition == TimePosition.invisible`, skip drawing timestamp.
  - Update `timestampText` string with `viewModel.formattedCurrentTotalTime`.
  - Calculate `(x, y)` coordinate based on `viewModel.timePosition`:
    - `topLeft`: `(10.0f, 10.0f)`
    - `topRight`: `(windowWidth - textWidth - 10.0f, 10.0f)`
    - `bottomRight`: `(windowWidth - textWidth - 10.0f, windowHeight - textHeight - 10.0f)`
    - `bottomLeft`: `(10.0f, windowHeight - textHeight - 10.0f)`
  - Draw text using `sdlffcd_text_draw_with_bg` and present app with `sdlffcd_app_present`.

---

### Player Controller (`source/player_controller.d`)

#### [MODIFY] `source/player_controller.d`
- Add `initialize(ref AppContext appContext)` and `destroy()` to manage `View` initialization and cleanup.
- Fix `cycleTimePosition()` to cycle `viewModel.timePosition` through `TimePosition` values.
- Handle key `SDLFFCD_KEY_T` (or 'T') in `handleKeyPress()` to trigger `cycleTimePosition()`.
- Update `update(ref AppContext appContext)`:
  - Synchronize `playerModel.timePosition = appContext.player.getCurrentPts();` and `playerModel.timeDuration = appContext.player.getDuration();`.
  - When `playerModel.consumesUpdate()`, format `viewModel.formattedCurrentTotalTime`.
  - When `state.frameRendered` or `dirty`, invoke `view.render(appContext.app, viewModel)`.
- Remove duplicate `Hms1000` and `formatTimestamp` declarations.

---

### Application Context (`source/app_context.d`)

#### [MODIFY] `source/app_context.d`
- Remove `timestampFont` and `timestampText` fields.
- Remove font opening and text creation from `initialize()`.
- Remove `renderTimestamp()` method.
- Remove font and text destruction from `destroy()`.
- Remove `formatTimestamp()` function and its unittests (now in `models.d`).

---

### Main Entrypoint (`source/app.d`)

#### [MODIFY] `source/app.d`
- Call `playerController.initialize(appContext)` after initializing `appContext`.
- Add `scope(exit) playerController.destroy();` for clean shutdown.
- Update help log string to include key `[T] Cycle Timestamp Position`.

---

## Verification Plan

### Automated Tests
- Run `dub test` to ensure all unittests (including `formatTimestamp` unittests in `models.d`) pass without errors.
```bash
dub test
```

### Manual Verification
- Run `dub run` to launch video player with `samplevideo.mp4`.
- Verify timestamp overlay is rendered correctly during playback.
- Press `T` key to cycle timestamp position through `topLeft`, `topRight`, `bottomRight`, `bottomLeft`, `invisible`.
- Press `Q` or `ESC` to quit and ensure clean exit without memory leaks or crashes.
