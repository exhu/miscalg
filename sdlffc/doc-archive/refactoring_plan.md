# Refactoring Plan — `sdlffc` (Confirmed)

## Goal

Refactor the SDL3 + FFmpeg video-player to fix bugs, clean up warnings, and introduce a proper
**frame-decoding ring buffer with PTS-based wall-clock frame timing**, replacing the current
tightly-coupled ping-pong between the video thread and main thread.

---

## Confirmed Scope

| Item | Decision |
|------|----------|
| Frame-decoding ring buffer + frame timing | ✅ Include |
| `PRId64` for `stream->duration` | ✅ Use portable format |
| Fix wrong `sizeof` in `mailbox_init` | ✅ Fix |
| Fix spurious-wakeup in `mailbox_receive_and_lock` | ✅ Fix |
| Fix resource leak in `sdlffclib_free_video_file_ctx` | ✅ Fix |
| Remove dead `SDL_RemoveTimer` call | ✅ Remove |
| Add comment explaining `(void)pts` | ✅ Add |
| Remove `timer_id` from `_SdlffContext` | ✅ Remove |
| Dynamic vs static context | Keep singleton; `memset` on re-init |

---

## Architecture Overview

### Current (ping-pong, no timing)

```mermaid
sequenceDiagram
    participant V as Video Thread
    participant M as Main Thread
    V->>M: MTC_CREATE_TEXTURE_FOR_FRAME
    M-->>V: VTC_FILL_TEXTURE (+ locked ptr)
    V->>V: sws_scale into locked buffer
    V->>M: MTC_RENDER_FRAME
    M-->>V: VTC_NEXT_FRAME
    Note over V,M: Runs as fast as decode+render; no timing
```

### New (ring buffer + PTS timing)

```mermaid
sequenceDiagram
    participant V as Video Thread
    participant Q as FrameQueue (8 slots)
    participant M as Main Thread

    V->>Q: frame_queue_push(frame, pts) [blocks if full]
    Q-->>M: frame_queue_try_pop(elapsed) [non-blocking]
    M->>M: convert (sws_scale) + render
    Note over M: SDL_WaitEventTimeout(1ms) loop; renders when wall_clock >= pts
    V->>M: MTC_VIDEO_END (on flush)
```

**Key properties of the new design:**
- Video thread decodes as fast as possible, up to 8 frames ahead
- Main thread renders each frame at the correct wall-clock time based on PTS
- All SDL/GPU operations remain on the main thread (sws_scale moves there)
- Quit is cooperative: `SDL_AtomicInt quit_requested` flag + `frame_queue_signal_quit()`

---

## Proposed Changes

### Component A — New: `FrameQueue`

---

#### [NEW] `frame_queue.h`

```c
#pragma once
#include <stdbool.h>
#include <SDL3/SDL_atomic.h>
#include <SDL3/SDL_mutex.h>
#include <libavutil/frame.h>

#define FRAME_QUEUE_SIZE 8

typedef struct {
    AVFrame      *frames[FRAME_QUEUE_SIZE];
    double        pts[FRAME_QUEUE_SIZE];   ///< presentation time in seconds from first frame
    int           write_idx;
    int           read_idx;
    int           count;
    SDL_Mutex    *mutex;
    SDL_Condition *not_full;
    SDL_Condition *not_empty;
} FrameQueue;

bool     frame_queue_init(FrameQueue *q);
void     frame_queue_done(FrameQueue *q);

/// Blocks until space is available or quit_requested != 0.
/// Returns true on success; false if aborted (caller must unref+free frame).
bool     frame_queue_push(FrameQueue *q, AVFrame *frame, double pts,
                          SDL_AtomicInt *quit_requested);

/// Non-blocking: pops and returns head frame if its pts <= max_pts (caller owns).
/// Returns NULL if queue is empty or head pts > max_pts.
AVFrame *frame_queue_try_pop(FrameQueue *q, double max_pts);

/// Drain all frames and signal not_full (used during shutdown).
void     frame_queue_flush(FrameQueue *q);
```

---

#### [NEW] `frame_queue.c`

```c
#include "frame_queue.h"
#include <SDL3/SDL_log.h>

bool frame_queue_init(FrameQueue *q) {
    memset(q, 0, sizeof(*q));
    q->mutex     = SDL_CreateMutex();
    q->not_full  = SDL_CreateCondition();
    q->not_empty = SDL_CreateCondition();
    return q->mutex && q->not_full && q->not_empty;
}

void frame_queue_done(FrameQueue *q) {
    frame_queue_flush(q);
    SDL_DestroyCondition(q->not_empty);
    SDL_DestroyCondition(q->not_full);
    SDL_DestroyMutex(q->mutex);
}

bool frame_queue_push(FrameQueue *q, AVFrame *frame, double pts,
                      SDL_AtomicInt *quit_requested) {
    SDL_LockMutex(q->mutex);
    while (q->count == FRAME_QUEUE_SIZE &&
           !SDL_GetAtomicInt(quit_requested)) {
        SDL_WaitCondition(q->not_full, q->mutex);
    }
    if (SDL_GetAtomicInt(quit_requested)) {
        SDL_UnlockMutex(q->mutex);
        return false;
    }
    int idx = q->write_idx;
    q->frames[idx] = frame;
    q->pts[idx]    = pts;
    q->write_idx   = (idx + 1) % FRAME_QUEUE_SIZE;
    q->count++;
    SDL_SignalCondition(q->not_empty);
    SDL_UnlockMutex(q->mutex);
    return true;
}

AVFrame *frame_queue_try_pop(FrameQueue *q, double max_pts) {
    SDL_LockMutex(q->mutex);
    AVFrame *frame = NULL;
    if (q->count > 0 && q->pts[q->read_idx] <= max_pts) {
        frame = q->frames[q->read_idx];
        q->frames[q->read_idx] = NULL;
        q->read_idx = (q->read_idx + 1) % FRAME_QUEUE_SIZE;
        q->count--;
        SDL_SignalCondition(q->not_full);
    }
    SDL_UnlockMutex(q->mutex);
    return frame;
}

void frame_queue_flush(FrameQueue *q) {
    SDL_LockMutex(q->mutex);
    while (q->count > 0) {
        AVFrame *f = q->frames[q->read_idx];
        q->frames[q->read_idx] = NULL;
        q->read_idx = (q->read_idx + 1) % FRAME_QUEUE_SIZE;
        q->count--;
        if (f) { av_frame_unref(f); av_frame_free(&f); }
    }
    SDL_BroadcastCondition(q->not_full);
    SDL_UnlockMutex(q->mutex);
}
```

---

### Component B — Bug Fixes

---

#### [MODIFY] `mailbox.c` — Fix spurious-wakeup guard in timeout path

```diff
 } else {
-    SDL_WaitConditionTimeout(mb->condition, mb->mutex, timeout);
+    /* Guard against spurious wakeups: re-check is_set after each wake */
+    while (!mb->is_set) {
+        if (!SDL_WaitConditionTimeout(mb->condition, mb->mutex, timeout)) {
+            break; /* genuine timeout */
+        }
+    }
 }
```

---

#### [MODIFY] `sdlffclib.c` — Fix wrong `sizeof` for `video_thread_mailbox`

```diff
  mailbox_init(&context->video_thread_mailbox,
               &context->video_thread_mailbox_data,
-              sizeof(context->main_thread_mailbox_data));
+              sizeof(context->video_thread_mailbox_data));
```

---

#### [MODIFY] `sdlffclib.c` — Fix resource leak in `sdlffclib_free_video_file_ctx`

```diff
 static void sdlffclib_free_video_file_ctx(SdlffVideoFileContext *ctx) {
-  if (ctx->ic) {
-    if (ctx->frame) av_frame_free(&ctx->frame);
-    if (ctx->pkt)   av_packet_free(&ctx->pkt);
-    if (ctx->audio_context) avcodec_free_context(&ctx->audio_context);
-    if (ctx->video_context) avcodec_free_context(&ctx->video_context);
-    if (ctx->ic)    avformat_close_input(&ctx->ic);
-  }
+  /* Guard each pointer independently — resources may be allocated
+     even when ctx->ic is NULL (e.g. if avformat_open_input failed late). */
+  if (ctx->frame)         av_frame_free(&ctx->frame);
+  if (ctx->pkt)           av_packet_free(&ctx->pkt);
+  if (ctx->audio_context) avcodec_free_context(&ctx->audio_context);
+  if (ctx->video_context) avcodec_free_context(&ctx->video_context);
+  if (ctx->ic)            avformat_close_input(&ctx->ic);
 }
```

---

#### [MODIFY] `sdlffclib.c` — `sdlffclib_init()`: zero stale static state on re-init

```diff
 bool sdlffclib_init(SdlffContext **out_context) {
   static SdlffContext global_context = {0};
+  memset(&global_context, 0, sizeof(global_context));
```

Also init `frame_queue` and `quit_requested`:

```diff
+  SDL_SetAtomicInt(&context->quit_requested, 0);
+  frame_queue_init(&context->frame_queue);
   context->main_thread_event = SDL_RegisterEvents(1);
```

---

### Component C — Ring Buffer Integration

---

#### [MODIFY] `sdlffclib_private.h` — Update `_SdlffContext` and command enums

```diff
+#include "frame_queue.h"

 typedef enum {
-  MTC_CREATE_TEXTURE_FOR_FRAME,
-  MTC_RENDER_FRAME,
   MTC_VIDEO_END,
 } MainThreadCommand;

 typedef enum {
   VTC_QUIT,
   VTC_PLAY,
-  VTC_FILL_TEXTURE,
-  VTC_NEXT_FRAME,
 } VideoThreadCommand;

 struct _SdlffContext {
   SDL_Window   *window;
   SDL_Renderer *renderer;
   SDL_Texture  *video_texture;
-  void         *locked_pixels;    /* removed: now local to render function */
-  int           locked_pitch;
   SdlffVideoFileContext video_file_ctx;
-  SDL_TimerID   timer_id;         /* removed: never used */
   Uint32        main_thread_event;
   SDL_Thread   *video_thread;
   MailBox       video_thread_mailbox;
   MailBox       main_thread_mailbox;
   MainThreadCommand  main_thread_mailbox_data;
   VideoThreadCommand video_thread_mailbox_data;
+  FrameQueue    frame_queue;
+  SDL_AtomicInt quit_requested;
+  Uint64        play_start_time;  ///< SDL_GetTicksNS() when playback started
 };
```

---

#### [MODIFY] `sdlffclib.c` — Rework `video_thread_cb`

Remove per-frame ping-pong; push decoded frames into `frame_queue`:

```c
static int SDLCALL video_thread_cb(void *data) {
    SdlffContext *context = (SdlffContext *)data;
    SDL_Log("video thread started.");

    /* Wait for VTC_PLAY or VTC_QUIT */
    const bool has_msg = mailbox_receive_and_lock(&context->video_thread_mailbox, -1);
    const VideoThreadCommand cmd = context->video_thread_mailbox_data;
    mailbox_unlock(&context->video_thread_mailbox);
    if (!has_msg || cmd == VTC_QUIT) {
        SDL_Log("video thread exit (before play).");
        return 0;
    }

    SDL_Log("video thread: play started.");
    SdlffVideoFileContext *ctx = &context->video_file_ctx;

    while (!SDL_GetAtomicInt(&context->quit_requested)) {
        bool decoded_frame = false;

        while (!decoded_frame && !ctx->flushing &&
               !SDL_GetAtomicInt(&context->quit_requested)) {
            read_and_decode_next_packet(context);

            if (ctx->video_context &&
                avcodec_receive_frame(ctx->video_context, ctx->frame) >= 0) {
                decoded_frame = true;

                double pts =
                    ((double)ctx->frame->pts * ctx->video_context->pkt_timebase.num) /
                    ctx->video_context->pkt_timebase.den;
                if (ctx->first_pts < 0.0)
                    ctx->first_pts = pts;
                pts -= ctx->first_pts;

                /* Clone frame for queue ownership */
                AVFrame *qframe = av_frame_alloc();
                if (qframe && av_frame_ref(qframe, ctx->frame) >= 0) {
                    if (!frame_queue_push(&context->frame_queue, qframe, pts,
                                         &context->quit_requested)) {
                        av_frame_unref(qframe);
                        av_frame_free(&qframe);
                    }
                } else {
                    av_frame_free(&qframe);
                }
                av_frame_unref(ctx->frame);
            }
        }

        if (ctx->flushing && !decoded_frame) {
            MainThreadCommand mtc = MTC_VIDEO_END;
            mailbox_send(&context->main_thread_mailbox, &mtc, sizeof(mtc));
            send_main_thread_event(context);
            break;
        }
    }

    SDL_Log("video thread exit.");
    return 0;
}
```

---

#### [MODIFY] `sdlffclib.c` — Rework `sdlffclib_main_loop`

Replace `SDL_WaitEvent` with `SDL_WaitEventTimeout(1)` (1 ms); check PTS on each tick:

```c
void sdlffclib_main_loop(SdlffContext *context) {
    SDL_Event event;
    bool should_break = false;

    context->play_start_time = SDL_GetTicksNS();
    VideoThreadCommand command = VTC_PLAY;
    mailbox_send(&context->video_thread_mailbox, &command, sizeof(command));

    while (!should_break) {
        /* 1 ms timeout so we can check frame timing every tick */
        SDL_WaitEventTimeout(&event, 1);

        switch (event.type) {
        case SDL_EVENT_QUIT:
            should_break = true;
            break;
        case SDL_EVENT_KEY_DOWN:
            should_break = handle_key_should_quit(&event.key);
            break;
        default:
            if (event.type == context->main_thread_event) {
                if (mailbox_receive_and_lock(&context->main_thread_mailbox,
                                            1000 / 60)) {
                    const MainThreadCommand cmd =
                        context->main_thread_mailbox_data;
                    mailbox_unlock(&context->main_thread_mailbox);
                    if (cmd == MTC_VIDEO_END) {
                        SDL_Log("main thread: video end.");
                        should_break = true;
                    }
                } else {
                    mailbox_unlock(&context->main_thread_mailbox);
                }
            }
            break;
        }

        if (!should_break) {
            double elapsed =
                (double)(SDL_GetTicksNS() - context->play_start_time) / 1e9;
            AVFrame *frame =
                frame_queue_try_pop(&context->frame_queue, elapsed);
            if (frame) {
                render_frame_main_thread(context, frame);
                av_frame_unref(frame);
                av_frame_free(&frame);
            }
        }
    }
    SDL_Log("Quit.");
}
```

---

#### [MODIFY] `sdlffclib.c` — New `render_frame_main_thread` (replaces two old functions)

Combines texture creation, sws_scale, lock/unlock, and render in one main-thread function:

```c
static void render_frame_main_thread(SdlffContext *context, AVFrame *frame) {
    if (!create_or_reuse_cached_texture(context, frame, &context->video_texture))
        return;

    void *pixels = NULL;
    int pitch = 0;
    if (!SDL_LockTexture(context->video_texture, NULL, &pixels, &pitch)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "SDL_LockTexture failed: %s", SDL_GetError());
        return;
    }

    /* Convert frame pixels directly into the locked texture buffer */
    /* (sws context is cached in texture properties, same as before) */
    fill_texture_with_frame_data_into(frame, pixels, pitch);

    SDL_UnlockTexture(context->video_texture);

    SDL_SetRenderDrawColor(context->renderer, 0, 0, 0, 255);
    SDL_RenderClear(context->renderer);
    if (frame->linesize[0] < 0) {
        SDL_FRect src = { 0.0f, 0.0f,
                          (float)frame->width, (float)frame->height };
        SDL_RenderTextureRotated(context->renderer, context->video_texture,
                                 &src, NULL, 0.0, NULL, SDL_FLIP_VERTICAL);
    } else {
        SDL_FRect src = { 0.0f, 0.0f,
                          (float)frame->width, (float)frame->height };
        SDL_RenderTexture(context->renderer, context->video_texture, &src, NULL);
    }
    SDL_RenderPresent(context->renderer);
}
```

`fill_texture_with_frame_data_into` is a refactored version of the old `fill_texture_with_frame_data` that takes `pixels`/`pitch` directly instead of reading from context fields.

---

#### [MODIFY] `sdlffclib.c` — Update `sdlffclib_done` to drain queue before join

```diff
 void sdlffclib_done(SdlffContext **out_context) {
   SdlffContext *context = *out_context;
+  /* Signal video thread to quit, then unblock it if blocked in frame_queue_push */
+  SDL_SetAtomicInt(&context->quit_requested, 1);
+  frame_queue_flush(&context->frame_queue);
   VideoThreadCommand command = VTC_QUIT;
   mailbox_send(&context->video_thread_mailbox, &command, sizeof(command));
   SDL_WaitThread(context->video_thread, NULL);
   mailbox_done(&context->main_thread_mailbox);
   mailbox_done(&context->video_thread_mailbox);
+  frame_queue_done(&context->frame_queue);
   ...
 }
```

---

### Component D — Code Cleanliness

---

#### [MODIFY] `sdlffclib.c` — `sdlffclib_fileinfo`: use `PRId64` for `stream->duration`

```diff
+#include <inttypes.h>
 ...
-    SDL_Log("Duration: %ld", stream->duration);
+    SDL_Log("Duration: %" PRId64, stream->duration);
```

---

#### [MODIFY] `sdlffclib.c` — Remove dead `SDL_RemoveTimer` call

```diff
-  SDL_RemoveTimer(context->timer_id);
   SDL_Log("Quit.");
```

---

#### [MODIFY] `sdlffclib.c` — Add comment for `(void)pts`

```diff
-            (void)pts;
+            /* pts will be used for timing once frame queue + wall clock is in place */
+            (void)pts;
```

> [!NOTE]
> This comment becomes a TODO marker only — the actual `pts` variable is still computed and used in the new `frame_queue_push` call. The `(void)pts;` suppression line may be removable entirely once the ring buffer is in place.

---

#### [MODIFY] `meson.build` — Add `frame_queue.c` to sources

```diff
 src = ['sdlffc.c',
        'sdlffclib.c',
        'mailbox.c',
+       'frame_queue.c',
       ]
```

---

## Verification Plan

### Automated Tests

```sh
# Full build — confirms zero new compile errors
./build.sh
```

### Manual Verification

1. **Build passes** with no new warnings under `warning_level=everything`
2. **Video plays correctly** — `./run.sh` with `resenije.mp4`; frames advance at correct speed, `Q` quits cleanly
3. **Frame timing observable** — video should no longer play "as fast as possible"; frame rate should match source
4. **Valgrind (optional)** — `valgrind --leak-check=full ./_build/sdlffc resenije.mp4` to confirm no new leaks from frame_queue allocations
