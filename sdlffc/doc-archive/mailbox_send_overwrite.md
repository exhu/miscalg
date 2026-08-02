# Explanation of `mailbox_send_overwrite` Usage

## Overview

In `sdlffc`, a `MailBox` ([`mailbox.h`](../mailbox.h)) is a lightweight, one-way, single-slot thread communication primitive implemented using SDL3 mutexes (`SDL_Mutex`) and condition variables (`SDL_Condition`).

`mailbox_send_overwrite` ([`mailbox.h`](../mailbox.h#L21), [`mailbox.c`](../mailbox.c#L42-L55)) sends a message into the mailbox using **non-blocking, lossy semantics**. If an unconsumed message is already sitting in the mailbox slot, it is immediately overwritten with the newest payload.

---

## Mechanism: `mailbox_send_overwrite` vs. `mailbox_send`

| Function | Behavior when slot is full (`is_set == true`) |
| :--- | :--- |
| **`mailbox_send`** | **Blocking**: Sender thread sleeps on `empty_condition` until the receiver thread consumes the message and calls `mailbox_unlock`. |
| **`mailbox_send_overwrite`** | **Non-blocking / Overwriting**: Immediately overwrites `mb->data` via `memcpy`, sets `is_set = true`, and signals `mb->condition`. |

### Implementation (`mailbox.c`)
```c
bool mailbox_send_overwrite(MailBox *mb, const void *new_data_value, size_t data_size) {
  SDL_LockMutex(mb->mutex);
  bool result = false;
  if (data_size == mb->data_size) {
    memcpy(mb->data, new_data_value, data_size);
    mb->is_set = true;
    result = true;
  } else {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "data_size mismatch!");
  }
  SDL_UnlockMutex(mb->mutex);
  SDL_SignalCondition(mb->condition);
  return result;
}
```

---

## Usage in the Project

`mailbox_send_overwrite` is used in three key areas across the project:

### 1. Dispatching Seek Commands (`sdlffclib.c:179`)
```c
/* Send seek command to video thread */
VideoThreadMsg msg = { .command = VTC_SEEK, .seek_target_sec = target_pos };
mailbox_send_overwrite(&context->video_thread_mailbox, &msg, sizeof(msg));
```
- **Context:** When the user requests a seek to a specific timestamp (`sdlffclib_seek`).
- **Why overwrite:** Rapid seeking or scrubbing generates multiple seek events. Overwriting ensures the video thread always receives the newest target timestamp without blocking the main UI thread.

### 2. Kicking Off Playback (`sdlffclib.c:189`)
```c
/* Record the wall-clock start time and kick the video thread */
context->play_start_time = SDL_GetTicksNS();
VideoThreadMsg command = { .command = VTC_PLAY, .seek_target_sec = 0.0 };
mailbox_send_overwrite(&context->video_thread_mailbox, &command, sizeof(command));
```
- **Context:** Executed when entering `sdlffclib_main_loop` to start decoding and playback.
- **Why overwrite:** Non-blocking dispatch ensures start commands are delivered to the video decoding thread without startup delays.

### 3. Notifying Main Thread of Video Stream EOF (`playback_thread.c:157`)
```c
if (ctx->flushing && !decoded_frame) {
  /* All frames pushed; tell main thread the stream is finished */
  MainThreadCommand mtc = MTC_VIDEO_END;
  mailbox_send_overwrite(&context->main_thread_mailbox, &mtc, sizeof(mtc));
  send_main_thread_event(context);
  break;
}
```
- **Context:** Sent by the video decoding thread to `main_thread_mailbox` when EOF is reached and all frames have been pushed.
- **Why overwrite:** Ensures the video thread can send the final end-of-stream signal and terminate cleanly without risk of blocking if an earlier unconsumed command is still in the mailbox.
