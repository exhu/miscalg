#include "sdlffclib.h"
#include "demux_decoder.h"
#include "frame_queue.h"
#include "mailbox.h"
#include "playback_thread.h"
#include "sdlffclib_private.h"
#include "video_render.h"

// sdl
#include <SDL3/SDL_events.h>
#include <SDL3/SDL_init.h>
#include <SDL3/SDL_keyboard.h>
#include <SDL3/SDL_keycode.h>
#include <SDL3/SDL_log.h>
#include <SDL3/SDL_render.h>
#include <SDL3/SDL_thread.h>
#include <SDL3/SDL_timer.h>
#include <SDL3/SDL_video.h>

// std
#include <stdbool.h>
#include <string.h>

static inline double seconds_from_nanoseconds(Uint64 ns) {
  return (double)ns / 1.0e9;
}

bool sdlffclib_init(SdlffContext **out_context) {
  static SdlffContext global_context = {0};
  /* Zero out any stale state left from a previous run */
  memset(&global_context, 0, sizeof(global_context));

  SDL_SetAppMetadata("sdlffc", "0.1", "com.github.exhu.miscalg.sdlffc");

  if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO)) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Failed to init: %s",
                 SDL_GetError());
    return false;
  }

  SdlffContext *context = &global_context;
  context->exit_at_end = true;
  *out_context = context;

  SDL_SetAtomicInt(&context->quit_requested, 0);
  if (!frame_queue_init(&context->frame_queue)) {
    SDL_Quit();
    return false;
  }

  context->main_thread_event = SDL_RegisterEvents(1);

  if (!SDL_CreateWindowAndRenderer("hello sdl!", 1280, 720,
                                   SDL_WINDOW_RESIZABLE, &context->window,
                                   &context->renderer)) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                 "Failed to create window and renderer: %s", SDL_GetError());
    frame_queue_done(&context->frame_queue);
    SDL_Quit();
    return false;
  }

  if (!mailbox_init(&context->main_thread_mailbox,
                    &context->main_thread_mailbox_data,
                    sizeof(context->main_thread_mailbox_data)) ||
      !mailbox_init(&context->video_thread_mailbox,
                    &context->video_thread_mailbox_data,
                    sizeof(context->video_thread_mailbox_data))) {
    SDL_DestroyRenderer(context->renderer);
    SDL_DestroyWindow(context->window);
    frame_queue_done(&context->frame_queue);
    SDL_Quit();
    return false;
  }

  context->video_thread =
      SDL_CreateThread(&video_thread_cb, "video-thread", context);
  if (!context->video_thread) {
    mailbox_done(&context->main_thread_mailbox);
    mailbox_done(&context->video_thread_mailbox);
    SDL_DestroyRenderer(context->renderer);
    SDL_DestroyWindow(context->window);
    frame_queue_done(&context->frame_queue);
    SDL_Quit();
    return false;
  }

  SDL_SetWindowMinimumSize(context->window, 320, 240);
  if (!SDL_SetRenderVSync(context->renderer, SDL_RENDERER_VSYNC_ADAPTIVE)) {
    SDL_SetRenderVSync(context->renderer, 1);
  }
  SDL_ShowWindow(context->window);
  return true;
}

void sdlffclib_done(SdlffContext **out_context) {
  if (!out_context || !*out_context) {
    return;
  }
  SdlffContext *context = *out_context;

  /* Signal video thread to stop and unblock it if blocked in frame_queue_push
   */
  SDL_SetAtomicInt(&context->quit_requested, 1);
  frame_queue_flush(&context->frame_queue);
  if (context->video_thread) {
    SDL_WaitThread(context->video_thread, NULL);
  }

  if (context->audio_stream) {
    SDL_DestroyAudioStream(context->audio_stream);
    context->audio_stream = NULL;
  }

  mailbox_done(&context->main_thread_mailbox);
  mailbox_done(&context->video_thread_mailbox);
  frame_queue_done(&context->frame_queue);

  if (context->video_texture) {
    SDL_DestroyTexture(context->video_texture);
    context->video_texture = NULL;
  }

  sdlffclib_free_video_file_ctx(&context->video_file_ctx);

  /// free sdl resources
  if (context->renderer) {
    SDL_DestroyRenderer(context->renderer);
  }
  if (context->window) {
    SDL_DestroyWindow(context->window);
  }
  memset(*out_context, 0, sizeof(SdlffContext));
  *out_context = NULL;
  SDL_Quit();
}

static void handle_seek(SdlffContext *context, double offset_sec) {
  SdlffVideoFileContext *ctx = &context->video_file_ctx;
  if (!ctx->ic)
    return;

  Uint64 now = context->paused ? context->pause_start_ticks : SDL_GetTicksNS();
  double current_pos = seconds_from_nanoseconds(now - context->play_start_time);
  double target_pos = current_pos + offset_sec;
  if (target_pos < 0.0) {
    target_pos = 0.0;
  }
  if (ctx->ic->duration != AV_NOPTS_VALUE) {
    double duration = (double)ctx->ic->duration / AV_TIME_BASE;
    if (target_pos > duration) {
      target_pos = duration;
    }
  }

  SDL_Log("Seek requested: %.2f -> %.2f (offset: %+.1fs)", current_pos,
          target_pos, offset_sec);

  /* Flush frame queue so main thread stops presenting pre-seek frames */
  frame_queue_flush(&context->frame_queue);

  if (context->audio_stream) {
    SDL_ClearAudioStream(context->audio_stream);
  }

  /* Update playback clock baseline */
  context->play_start_time = now - (Uint64)(target_pos * 1.0e9);

  /* Send seek command to video thread */
  VideoThreadMsg msg = {.command = VTC_SEEK, .seek_target_sec = target_pos};
  mailbox_send_overwrite(&context->video_thread_mailbox, &msg, sizeof(msg));
}

static void handle_pause_key(SdlffContext *context,
                             const SDL_KeyboardEvent *key) {
  if (!key->repeat) {
    if (context->paused) {
      Uint64 now = SDL_GetTicksNS();
      context->play_start_time += (now - context->pause_start_ticks);
      context->paused = false;
      if (context->audio_stream) {
        SDL_ResumeAudioStreamDevice(context->audio_stream);
      }
      SDL_Log("Resumed video playback");
    } else {
      context->pause_start_ticks = SDL_GetTicksNS();
      context->paused = true;
      if (context->audio_stream) {
        SDL_PauseAudioStreamDevice(context->audio_stream);
      }
      SDL_Log("Paused video playback");
    }
    redraw_current_frame(context);
  }
}

static void handle_osd_key(SdlffContext *context,
                           const SDL_KeyboardEvent *key) {
  if (!key->repeat) {
    context->show_overlay = !context->show_overlay;
    SDL_Log("Timestamp overlay toggled: %s",
            context->show_overlay ? "ON" : "OFF");
    redraw_current_frame(context);
  }
}

/// all keyboard handling here. returns true to quit
static bool handle_key_should_quit(SdlffContext *context,
                                   const SDL_KeyboardEvent *key) {
  switch (key->key) {
  case SDLK_Q:
  case SDLK_ESCAPE:
    return true;
    break;
  case SDLK_SPACE:
    handle_pause_key(context, key);
    context->exit_at_end = false;
    break;
  case SDLK_O:
    handle_osd_key(context, key);
    break;
  case SDLK_LEFT:
    handle_seek(context, -5.0);
    context->exit_at_end = false;
    break;
  case SDLK_RIGHT:
    handle_seek(context, 5.0);
    context->exit_at_end = false;
    break;
  default:;
  }
  return false;
}

void sdlffclib_main_loop(SdlffContext *context) {
  SDL_Event event;
  bool should_break = false;

  /* Record the wall-clock start time and kick the video thread */
  context->play_start_time = SDL_GetTicksNS();
  context->show_overlay = true;
  VideoThreadMsg command = {.command = VTC_PLAY, .seek_target_sec = 0.0};
  mailbox_send_overwrite(&context->video_thread_mailbox, &command,
                         sizeof(command));

  while (!should_break) {
    /* Calculate dynamic timeout based on next frame's PTS */
    double elapsed = context->paused
                         ? seconds_from_nanoseconds(context->pause_start_ticks -
                                                    context->play_start_time)
                         : seconds_from_nanoseconds(SDL_GetTicksNS() -
                                                    context->play_start_time);
    double next_pts = 0.0;
    Sint32 timeout_ms = 10; /* Fallback timeout if frame queue is empty */

    if (context->paused) {
      if (frame_queue_peek_pts(&context->frame_queue, &next_pts) &&
          next_pts <= elapsed) {
        timeout_ms = 0;
      } else {
        timeout_ms = 100;
      }
    } else if (frame_queue_peek_pts(&context->frame_queue, &next_pts)) {
      double delay_sec = next_pts - elapsed;
      if (delay_sec <= 0.0) {
        timeout_ms = 0; /* Frame is already due */
      } else {
        timeout_ms = (Sint32)(delay_sec * 1000.0);
        if (timeout_ms > 100) {
          timeout_ms = 100; /* Cap maximum wait time for event responsiveness */
        }
      }
    }

    if (SDL_WaitEventTimeout(&event, timeout_ms)) {
      switch (event.type) {
      case SDL_EVENT_QUIT:
        should_break = true;
        break;
      case SDL_EVENT_KEY_DOWN:
        should_break = handle_key_should_quit(context, &event.key);
        break;
      default:
        if (event.type == context->main_thread_event) {
          const bool has_cmd = mailbox_receive_and_lock(
              &context->main_thread_mailbox, 1000 / 60);
          if (has_cmd) {
            const MainThreadCommand cmd = context->main_thread_mailbox_data;
            mailbox_unlock(&context->main_thread_mailbox);
            if (cmd == MTC_VIDEO_END) {
              SDL_Log("main thread received video end command.");
              if (context->exit_at_end) {
                should_break = true;
              }
            }
          }
        }
        break;
      }
    }

    /* Pop and render any frame whose PTS has been reached.
       If multiple frames are ready (due to latency/lag), drop older frames
       so rendering catches up to real-time playback. */
    if (!should_break) {
      /* Convert nanoseconds (SDL_GetTicksNS) to seconds */
      double render_elapsed =
          context->paused
              ? seconds_from_nanoseconds(context->pause_start_ticks -
                                         context->play_start_time)
              : seconds_from_nanoseconds(SDL_GetTicksNS() -
                                         context->play_start_time);
      AVFrame *frame = NULL;
      AVFrame *next_frame = NULL;

      while ((next_frame = frame_queue_try_pop(&context->frame_queue,
                                               render_elapsed)) != NULL) {
        if (frame) {
          av_frame_free(&frame);
        }
        frame = next_frame;
      }

      if (frame) {
        render_frame_main_thread(context, frame);
        av_frame_free(&frame);
      }
    }
  }
  SDL_Log("Quit.");
}
