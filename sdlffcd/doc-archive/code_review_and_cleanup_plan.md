# Code Review & Refactoring Plan: Unused Functions and Quality Improvements

## Goal Description
Conduct a comprehensive review of `source/` (D application code) and `sdlffcd_clib/` (C library bridge), identifying all unused functions/declarations, dead model tracking, and recommending code quality & architecture improvements.

---

## Code Review & Audit Results

### 1. Unused / Uncalled C API Functions (`sdlffcd_clib`)
| Function | File | Status & Usage Analysis | Recommended Action |
|---|---|---|---|
| `sdlffcd_app_poll_events` | `sdlffcd_clib.c`, `sdlffcd_clib.h` | Implemented and exported, but never called in D app (`app.d` uses `sdlffcd_app_wait_events`). | **Retain as C API**: Useful non-blocking alternative in public C API library. Add doc comment. |
| `sdlffcd_app_wake` | `sdlffcd_clib.c`, `sdlffcd_clib.h` | Pushes custom SDL event to wake event loop. Never invoked by D app. | **Retain as C API**: Useful for async thread notification. Keep in library. |
| `sdlffcd_app_render` | `sdlffcd_clib.c`, `sdlffcd_clib.h` | Clears window & presents renderer. Unused because `player_view.d` does custom rendering + `sdlffcd_app_present`. | **Retain as C API**: Generic clear-and-present utility for simple non-video C apps using `sdlffcd_clib`. |
| `sdlffcd_text_draw` | `sdlffcd_clib.c`, `sdlffcd_clib.h` | Renders text without background rectangle. Unused in D app (app uses `sdlffcd_text_draw_with_bg`). | **Retain as C API**: Basic text rendering companion to `sdlffcd_text_draw_with_bg`. |
| `sdlffcd_app_need_redraw` / `sdlffcd_app_set_need_redraw` | `sdlffcd_clib.c`, `sdlffcd_clib.h` | Read/write accessors for `app->need_redraw`. Only tested in `sdlffcd_clib.d` unittest; app uses atomic `sdlffcd_app_check_and_clear_redraw`. | **Retain**: Public accessors for inspecting/setting redraw flags externally. |

> [!NOTE]
> Per user rules, `source/sdlffcd_clib.d` must strictly match `sdlffcd_clib.h`. Keeping these public C library functions intact guarantees API completeness and strict header alignment.

---

### 2. Unused / Dead D Code (`source/`)
| Symbol / Function | File | Status & Usage Analysis | Recommended Action |
|---|---|---|---|
| `FrameRingBuffer.clear()` | `source/frame_ring_buffer.d` | Method flushes queued slots without stream seek. Unused (`requestSeek` is used during seeks). | **Add unittest & retain**: Useful buffer management method. Add unit test coverage. |
| `VideoPlayer.isLoaded` | `source/video_player.d` | Property returning `loaded` status. Unused outside internal checks. | **Retain**: Standard getter method for video player state. |
| `VideoPlayer.isPaused` | `source/video_player.d` | Property returning pause status. Defined but never called. | **Integrate**: Wire into `PlayerController.update()` to sync `PlayerModel.isPaused`. |
| `VideoPlayer.redraw(app)` | `source/video_player.d` | High-level wrapper method for redrawing. Only called in unittest. | **Retain**: Public API method for explicit force-redraw requests. |
| `PlayerFields.isPaused` & `isLooping` | `source/models.d` | Struct fields in `PlayerFields`. Never populated in `PlayerController.update()`. | **Improve**: Populate `playerModel.isPaused` during update loop. Mark `isLooping` for future loop feature. |
| `EditFields` & `EditModel` | `source/models.d`, `source/player_controller.d` | Placeholder struct & model for video edit markers (`// TODO: implement edit features`). Currently tracked every frame in `PlayerController.update()`. | **Cleanup**: Remove empty `editModel.pollUpdate()` check from `PlayerController.update()` loop to avoid unnecessary per-frame tracking overhead until edit mode is implemented. |
| Backup files (`*~`) | Root, `source/`, `sdlffcd_clib/` | 11 editor backup files (`app_context.d~`, `models.d~`, `sdlffcd_clib.c~`, etc.) polluting the workspace. | **Delete**: Remove all `*~` backup clutter. |

---

## User Review Required

> [!IMPORTANT]
> Please confirm if you would like us to apply the proposed cleanups and improvements:
> 1. **Model state integration**: Sync `VideoPlayer.isPaused` to `PlayerModel.isPaused` in `PlayerController.update()`.
> 2. **Per-frame overhead reduction**: Remove dead `editModel.pollUpdate()` from `PlayerController.update()`.
> 3. **Clean up C key handling comment**: Clean up outdated `TODO` comment in `sdlffcd_clib.c`.
> 4. **Workspace cleanup**: Delete all leftover editor backup files (`*~`).
> 5. **Unit test additions**: Add unit tests for `FrameRingBuffer.clear()` and `VideoPlayer.isPaused`.

---

## Proposed Changes

### `source/models.d` & `source/player_controller.d`
#### [MODIFY] player_controller.d
- Remove unused per-frame `editModel.pollUpdate()` polling.
- Update `playerModel.isPaused = appContext.player.isPaused` in `PlayerController.update()`.

```diff
     if (appContext.player !is null)
     {
       playerModel.timePosition = appContext.player.getCurrentPts();
       playerModel.timeDuration = appContext.player.getDuration();
+      playerModel.isPaused = appContext.player.isPaused;
     }

     bool dirty = false;
     if (playerModel.pollUpdate())
     {
       dirty = true;
       viewModel.formattedCurrentTotalTime = formatTimestamp(playerModel.timePosition, playerModel.timeDuration);
     }
     if (viewModel.pollUpdate())
     {
       dirty = true;
     }
-    if (editModel.pollUpdate())
-    {
-      dirty = true;
-      // TODO: implement edit features
-    }
```

---

### `source/frame_ring_buffer.d`
#### [MODIFY] frame_ring_buffer.d
- Add unit test coverage for `FrameRingBuffer.clear()`.

---

### `sdlffcd_clib/sdlffcd_clib.c`
#### [MODIFY] sdlffcd_clib.c
- Clean up outdated key handling `TODO` comment in `process_single_event`.

---

### Workspace Cleanup
#### [DELETE] Editor backup files (`*~`)
- `source/app_context.d~`
- `source/models.d~`
- `source/observable.d~`
- `source/player_view.d~`
- `source/sdlffcd_clib.d~`
- `source/ui_view_model.d~`
- `sdlffcd_clib/AGENTS.md~`
- `sdlffcd_clib/meson.build~`
- `sdlffcd_clib/sdlffcd_clib.c~`
- `sdlffcd_clib/sdlffcd_clib.h~`
- `.editorconfig~`
- `README.md~`
- `TODO.org~`

---

## Verification Plan

### Automated Tests
1. Run D unit tests:
   ```bash
   dub test
   ```
2. Build executable:
   ```bash
   dub build
   ```

### Manual Verification
1. Run `./sdlffcd samplevideo.mp4` and verify video playback, pausing (Space/P), seeking (R/F, Left/Right), timestamp toggling (T), and quitting (Q/ESC).
