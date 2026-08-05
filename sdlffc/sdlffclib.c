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

// posix
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

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

  video_render_cleanup();

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

  Uint64 now = SDL_GetTicksNS();
  Uint64 pos_now = context->paused ? context->pause_start_ticks : now;
  double current_pos = seconds_from_nanoseconds(pos_now - context->play_start_time);

  double duration = -1.0;
  if (ctx->ic->duration != AV_NOPTS_VALUE && ctx->ic->duration > 0) {
    duration = (double)ctx->ic->duration / (double)AV_TIME_BASE;
  } else if (ctx->video_stream >= 0) {
    AVStream *st = ctx->ic->streams[ctx->video_stream];
    if (st && st->duration != AV_NOPTS_VALUE && st->duration > 0) {
      duration = (double)st->duration * av_q2d(st->time_base);
    }
  }

  if (duration > 0.0 && current_pos > duration) {
    current_pos = duration;
  }

  double target_pos = current_pos + offset_sec;
  if (target_pos < 0.0) {
    target_pos = 0.0;
  }
  if (duration > 0.0 && target_pos > duration) {
    target_pos = duration;
  }

  if (duration > 0.0 && target_pos < duration) {
    context->stream_ended = false;
  }

  SDL_Log("Seek requested: %.2f -> %.2f (offset: %+.1fs)", current_pos,
          target_pos, offset_sec);

  /* Flush frame queue so main thread stops presenting pre-seek frames */
  frame_queue_flush(&context->frame_queue);

  if (context->audio_stream) {
    SDL_ClearAudioStream(context->audio_stream);
  }

  if (context->paused) {
    context->pause_start_ticks = now;
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
    if (context->stream_ended) {
      return;
    }
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

double sdlffclib_get_min_seek_increment(const SdlffContext *context) {
  if (!context) return 1.0 / 30.0;
  if (context->min_seek_increment > 0.0) {
    return context->min_seek_increment;
  }
  const SdlffVideoFileContext *ctx = &context->video_file_ctx;
  if (ctx && ctx->ic && ctx->video_stream >= 0) {
    AVStream *st = ctx->ic->streams[ctx->video_stream];
    if (st) {
      if (st->avg_frame_rate.num > 0 && st->avg_frame_rate.den > 0) {
        return (double)st->avg_frame_rate.den / (double)st->avg_frame_rate.num;
      }
      if (st->r_frame_rate.num > 0 && st->r_frame_rate.den > 0) {
        return (double)st->r_frame_rate.den / (double)st->r_frame_rate.num;
      }
    }
    if (ctx->video_context && ctx->video_context->framerate.num > 0 &&
        ctx->video_context->framerate.den > 0) {
      return (double)ctx->video_context->framerate.den /
             (double)ctx->video_context->framerate.num;
    }
  }
  return 1.0 / 30.0;
}

static void validate_and_clamp_markers(SdlffContext *context) {
  if (!context) return;

  double duration = -1.0;
  if (context->video_file_ctx.ic) {
    if (context->video_file_ctx.ic->duration != AV_NOPTS_VALUE &&
        context->video_file_ctx.ic->duration > 0) {
      duration = (double)context->video_file_ctx.ic->duration / (double)AV_TIME_BASE;
    } else if (context->video_file_ctx.video_stream >= 0) {
      AVStream *st = context->video_file_ctx.ic->streams[context->video_file_ctx.video_stream];
      if (st && st->duration != AV_NOPTS_VALUE && st->duration > 0) {
        duration = (double)st->duration * av_q2d(st->time_base);
      }
    }
  }

  double step = sdlffclib_get_min_seek_increment(context);
  double max_frame_time = (duration > step) ? (duration - step) : 0.0;

  if (context->cut.in_point < 0.0) context->cut.in_point = 0.0;
  if (max_frame_time > 0.0 && context->cut.in_point > max_frame_time) {
    context->cut.in_point = max_frame_time;
  }

  if (context->cut.out_point < 0.0) context->cut.out_point = 0.0;
  if (max_frame_time > 0.0 && context->cut.out_point > max_frame_time) {
    context->cut.out_point = max_frame_time;
  }

  if (context->cut.in_point > context->cut.out_point) {
    double tmp = context->cut.in_point;
    context->cut.in_point = context->cut.out_point;
    context->cut.out_point = tmp;
    SDL_Log("Swapped IN and OUT markers so IN <= OUT (IN: %.3fs, OUT: %.3fs)",
            context->cut.in_point, context->cut.out_point);
  }
}

static bool get_export_filename(SdlffContext *context, char *out_filename, size_t max_filename_len) {
  if (!context || !context->file_path[0]) return false;

  validate_and_clamp_markers(context);

  double in_sec = context->cut.in_point;
  double out_sec = context->cut.out_point;

  int in_total = (int)in_sec;
  int in_h = in_total / 3600;
  int in_m = (in_total % 3600) / 60;
  int in_s = in_total % 60;
  int in_ms = (int)((in_sec - (double)in_total) * 1000.0 + 0.5);
  if (in_ms < 0) in_ms = 0; if (in_ms >= 1000) in_ms = 999;

  int out_total = (int)out_sec;
  int out_h = out_total / 3600;
  int out_m = (out_total % 3600) / 60;
  int out_s = out_total % 60;
  int out_ms = (int)((out_sec - (double)out_total) * 1000.0 + 0.5);
  if (out_ms < 0) out_ms = 0; if (out_ms >= 1000) out_ms = 999;

  char path_buf[1024];
  snprintf(path_buf, sizeof(path_buf), "%s", context->file_path);
  char *dot = strrchr(path_buf, '.');
  char *slash = strrchr(path_buf, '/');
  char ext[32] = "";
  if (dot && (!slash || dot > slash)) {
    snprintf(ext, sizeof(ext), "%s", dot);
    *dot = '\0';
  }

  snprintf(out_filename, max_filename_len,
           "%s_%02d_%02d_%02d_%03d_%02d_%02d_%02d_%03d%s",
           path_buf, in_h, in_m, in_s, in_ms, out_h, out_m, out_s, out_ms, ext);
  return true;
}

static bool export_file_exists(const char *filename) {
  if (!filename || !filename[0]) return false;
  FILE *f = fopen(filename, "rb");
  if (f) {
    fclose(f);
    return true;
  }
  return false;
}

static int SDLCALL ffmpeg_export_thread_cb(void *userdata) {
  SdlffContext *context = (SdlffContext *)userdata;
  char out_filename[1024];
  if (get_export_filename(context, out_filename, sizeof(out_filename))) {
    double in_sec = context->cut.in_point;
    double out_sec = context->cut.out_point;
    double step = context->min_seek_increment;
    if (step <= 0.0) step = 1.0 / 30.0;
    double cut_duration = (out_sec - in_sec) + step;

    int in_total = (int)in_sec;
    int in_h = in_total / 3600;
    int in_m = (in_total % 3600) / 60;
    int in_s = in_total % 60;
    int in_ms = (int)((in_sec - (double)in_total) * 1000.0 + 0.5);
    if (in_ms < 0) in_ms = 0; if (in_ms >= 1000) in_ms = 999;

    int dur_total = (int)cut_duration;
    int dur_h = dur_total / 3600;
    int dur_m = (dur_total % 3600) / 60;
    int dur_s = dur_total % 60;
    int dur_ms = (int)((cut_duration - (double)dur_total) * 1000.0 + 0.5);
    if (dur_ms < 0) dur_ms = 0; if (dur_ms >= 1000) dur_ms = 999;

    char in_time_str[64];
    snprintf(in_time_str, sizeof(in_time_str), "%02d:%02d:%02d.%03d",
             in_h, in_m, in_s, in_ms);
    char dur_time_str[64];
    snprintf(dur_time_str, sizeof(dur_time_str), "%02d:%02d:%02d.%03d",
             dur_h, dur_m, dur_s, dur_ms);

    printf("[EXPORT] ffmpeg -ss %s -i '%s' -t %s -c:v copy -c:a copy -map 0 '%s'\n",
           in_time_str, context->file_path, dur_time_str, out_filename);
    fflush(stdout);

    pid_t pid = fork();
    if (pid == 0) {
      /* child */
      execlp("ffmpeg", "ffmpeg",
             "-ss", in_time_str,
             "-i", context->file_path,
             "-t", dur_time_str,
             "-c:v", "copy", "-c:a", "copy", "-map", "0",
             out_filename, (char *)NULL);
      _exit(127);
    } else if (pid > 0) {
      int status;
      waitpid(pid, &status, 0);
    } else {
      SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "fork() failed");
    }
  }

  /* Signal main thread */
  MainThreadCommand msg = MTC_FFMPEG_DONE;
  mailbox_send_overwrite(&context->main_thread_mailbox, &msg, sizeof(msg));
  SDL_Event event;
  SDL_zero(event);
  event.type = context->main_thread_event;
  SDL_PushEvent(&event);
  return 0;
}

static void print_ffmpeg_command(SdlffContext *context) {
  if (!context || !context->file_path[0]) return;
  char out_filename[1024];
  if (!get_export_filename(context, out_filename, sizeof(out_filename))) return;

  double in_sec = context->cut.in_point;
  double out_sec = context->cut.out_point;

  double step = context->min_seek_increment;
  if (step <= 0.0) step = 1.0 / 30.0;

  /* Cut duration including full display duration of out frame */
  double cut_duration = (out_sec - in_sec) + step;

  /* IN time components */
  int in_total = (int)in_sec;
  int in_h = in_total / 3600;
  int in_m = (in_total % 3600) / 60;
  int in_s = in_total % 60;
  int in_ms = (int)((in_sec - (double)in_total) * 1000.0 + 0.5);
  if (in_ms < 0) in_ms = 0; if (in_ms >= 1000) in_ms = 999;

  char in_time_str[64];
  snprintf(in_time_str, sizeof(in_time_str), "%02d:%02d:%02d.%03d",
           in_h, in_m, in_s, in_ms);

  /* Format Duration string */
  int dur_total = (int)cut_duration;
  int dur_h = dur_total / 3600;
  int dur_m = (dur_total % 3600) / 60;
  int dur_s = dur_total % 60;
  int dur_ms = (int)((cut_duration - (double)dur_total) * 1000.0 + 0.5);
  if (dur_ms < 0) dur_ms = 0; if (dur_ms >= 1000) dur_ms = 999;
  char dur_time_str[64];
  snprintf(dur_time_str, sizeof(dur_time_str), "%02d:%02d:%02d.%03d",
           dur_h, dur_m, dur_s, dur_ms);

  printf("ffmpeg -ss %s -i \"%s\" -t %s -c:v copy -c:a copy -map 0 \"%s\"\n",
         in_time_str, context->file_path, dur_time_str, out_filename);
  fflush(stdout);
}

/// all keyboard handling here. returns true to quit
static bool handle_key_should_quit(SdlffContext *context,
                                   const SDL_KeyboardEvent *key) {
  if (context->ffmpeg_busy) {
    snprintf(context->ui.error_msg_text, sizeof(context->ui.error_msg_text), "waiting for the command to finish!");
    context->ui.error_msg_until_ticks = SDL_GetTicksNS() + 1000000000ULL;
    redraw_current_frame(context);
    return false;
  }

  Uint64 now = context->paused ? context->pause_start_ticks : SDL_GetTicksNS();
  double current_pos = seconds_from_nanoseconds(now - context->play_start_time);
  bool is_shift = (key->mod & SDL_KMOD_SHIFT) != 0;
  bool is_ctrl = (key->mod & SDL_KMOD_CTRL) != 0;

  switch (key->key) {
  case SDLK_Q:
  case SDLK_ESCAPE:
    if (context->cut.modified) {
      print_ffmpeg_command(context);
    }
    return true;
  case SDLK_SPACE:
    handle_pause_key(context, key);
    context->exit_at_end = false;
    break;
  case SDLK_V:
    if (!key->repeat) {
      context->ui.overlay_mode = (OverlayMode)((context->ui.overlay_mode + 1) % 3);
      redraw_current_frame(context);
    }
    break;
  case SDLK_B:
    handle_seek(context, -current_pos);
    context->looping = false;
    context->exit_at_end = false;
    break;
  case SDLK_E: {
    double duration = -1.0;
    if (context->video_file_ctx.ic) {
      if (context->video_file_ctx.ic->duration != AV_NOPTS_VALUE &&
          context->video_file_ctx.ic->duration > 0) {
        duration = (double)context->video_file_ctx.ic->duration / (double)AV_TIME_BASE;
      } else if (context->video_file_ctx.video_stream >= 0) {
        AVStream *st = context->video_file_ctx.ic->streams[context->video_file_ctx.video_stream];
        if (st && st->duration != AV_NOPTS_VALUE && st->duration > 0) {
          duration = (double)st->duration * av_q2d(st->time_base);
        }
      }
    }
    double step = sdlffclib_get_min_seek_increment(context);
    double last_frame = (duration > step) ? (duration - step) : 0.0;
    handle_seek(context, last_frame - current_pos);
    context->looping = false;
    context->exit_at_end = false;
    break;
  }
  case SDLK_I:
    if (is_shift) {
      handle_seek(context, context->cut.in_point - current_pos);
    } else if (!key->repeat) {
      context->cut.in_point = current_pos;
      validate_and_clamp_markers(context);
      context->cut.modified = true;
      SDL_Log("Set IN-marker to %.3fs (OUT: %.3fs)", context->cut.in_point, context->cut.out_point);
      redraw_current_frame(context);
    }
    context->looping = false;
    context->exit_at_end = false;
    break;
  case SDLK_O:
    if (is_shift) {
      handle_seek(context, context->cut.out_point - current_pos);
    } else if (!key->repeat) {
      context->cut.out_point = current_pos;
      validate_and_clamp_markers(context);
      context->cut.modified = true;
      SDL_Log("Set OUT-marker to %.3fs (IN: %.3fs)", context->cut.out_point, context->cut.in_point);
      redraw_current_frame(context);
    }
    context->looping = false;
    context->exit_at_end = false;
    break;
  case SDLK_L:
    if (!key->repeat) {
      context->looping = !context->looping;
      SDL_Log("Looping mode: %s", context->looping ? "ON" : "OFF");
      if (context->looping) {
        if (context->paused) {
          Uint64 ticks_now = SDL_GetTicksNS();
          context->play_start_time += (ticks_now - context->pause_start_ticks);
          context->paused = false;
          if (context->audio_stream) {
            SDL_ResumeAudioStreamDevice(context->audio_stream);
          }
        }
        Uint64 pos_ticks = context->paused ? context->pause_start_ticks : SDL_GetTicksNS();
        double pos_now = seconds_from_nanoseconds(pos_ticks - context->play_start_time);
        handle_seek(context, context->cut.in_point - pos_now);
      }
      redraw_current_frame(context);
    }
    break;
  case SDLK_RETURN:
  case SDLK_KP_ENTER:
    if (!key->repeat) {
      if (is_ctrl) {
        char out_filename[1024];
        get_export_filename(context, out_filename, sizeof(out_filename));
        if (export_file_exists(out_filename)) {
          snprintf(context->ui.error_msg_text, sizeof(context->ui.error_msg_text), "Export file already exists!");
          context->ui.error_msg_until_ticks = SDL_GetTicksNS() + 1000000000ULL;
          redraw_current_frame(context);
          SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION, "Export aborted: file '%s' already exists", out_filename);
        } else {
          if (!context->paused) {
            context->pause_start_ticks = SDL_GetTicksNS();
            context->paused = true;
            if (context->audio_stream) {
              SDL_PauseAudioStreamDevice(context->audio_stream);
            }
          }
          context->ffmpeg_busy = true;
          print_ffmpeg_command(context);
          SDL_Thread *export_thread = SDL_CreateThread(ffmpeg_export_thread_cb, "ffmpeg-export", context);
          if (export_thread) {
            SDL_DetachThread(export_thread);
          } else {
            context->ffmpeg_busy = false;
            SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Failed to create export thread");
          }
          redraw_current_frame(context);
        }
      } else {
        print_ffmpeg_command(context);
      }
    }
    break;
  case SDLK_LEFT:
    handle_seek(context, -5.0);
    context->looping = false;
    context->exit_at_end = false;
    break;
  case SDLK_RIGHT:
    handle_seek(context, 5.0);
    context->looping = false;
    context->exit_at_end = false;
    break;
  case SDLK_LEFTBRACKET: {
    if (!context->paused) {
      handle_pause_key(context, key);
    }
    double step = sdlffclib_get_min_seek_increment(context);
    handle_seek(context, -step);
    context->looping = false;
    context->exit_at_end = false;
    break;
  }
  case SDLK_RIGHTBRACKET: {
    if (!context->paused) {
      handle_pause_key(context, key);
    }
    double step = sdlffclib_get_min_seek_increment(context);
    handle_seek(context, step);
    context->looping = false;
    context->exit_at_end = false;
    break;
  }
  default:;
  }
  return false;
}

static double compute_elapsed(const SdlffContext *context, double duration) {
  double elapsed = context->paused
                       ? seconds_from_nanoseconds(context->pause_start_ticks -
                                                  context->play_start_time)
                       : seconds_from_nanoseconds(SDL_GetTicksNS() -
                                                  context->play_start_time);
  if (duration > 0.0 && (context->stream_ended || elapsed > duration)) {
    elapsed = duration;
  }
  return elapsed;
}

static Sint32 compute_event_timeout(SdlffContext *context, double elapsed) {
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
  return timeout_ms;
}

static bool process_main_thread_commands(SdlffContext *context) {
  bool should_break = false;
  const bool has_cmd = mailbox_receive_and_lock(
      &context->main_thread_mailbox, 1000 / 60);
  if (has_cmd) {
    const MainThreadCommand cmd = context->main_thread_mailbox_data;
    mailbox_unlock(&context->main_thread_mailbox);
    if (cmd == MTC_VIDEO_END) {
      SDL_Log("main thread received video end command.");
      context->stream_ended = true;
      if (context->exit_at_end && !context->looping) {
        should_break = true;
      }
    } else if (cmd == MTC_FFMPEG_DONE) {
      SDL_Log("main thread received ffmpeg export done command.");
      context->ffmpeg_busy = false;
      context->cut.modified = false;
      redraw_current_frame(context);
    }
  }
  return should_break;
}

static void pop_and_render_frames(SdlffContext *context, double duration) {
  /* Convert nanoseconds (SDL_GetTicksNS) to seconds */
  double render_elapsed =
      context->paused
          ? seconds_from_nanoseconds(context->pause_start_ticks -
                                     context->play_start_time)
          : seconds_from_nanoseconds(SDL_GetTicksNS() -
                                     context->play_start_time);
  if (duration > 0.0 && (context->stream_ended || render_elapsed > duration)) {
    render_elapsed = duration;
  }
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

void sdlffclib_main_loop(SdlffContext *context) {
  SDL_Event event;
  bool should_break = false;

  context->stream_ended = false;

  double duration = -1.0;
  if (context->video_file_ctx.ic) {
    if (context->video_file_ctx.ic->duration != AV_NOPTS_VALUE &&
        context->video_file_ctx.ic->duration > 0) {
      duration = (double)context->video_file_ctx.ic->duration / (double)AV_TIME_BASE;
    } else if (context->video_file_ctx.video_stream >= 0) {
      AVStream *st = context->video_file_ctx.ic->streams[context->video_file_ctx.video_stream];
      if (st && st->duration != AV_NOPTS_VALUE && st->duration > 0) {
        duration = (double)st->duration * av_q2d(st->time_base);
      }
    }
  }

  /* Record the wall-clock start time and kick the video thread */
  context->play_start_time = SDL_GetTicksNS();
  context->ui.overlay_mode = OVERLAY_TOP_LEFT;
  VideoThreadMsg command = {.command = VTC_PLAY, .seek_target_sec = 0.0};
  mailbox_send_overwrite(&context->video_thread_mailbox, &command,
                         sizeof(command));

  while (!should_break) {
    double elapsed = compute_elapsed(context, duration);

    if (context->looping) {
      double end_threshold = context->cut.out_point + context->min_seek_increment;
      if (elapsed >= end_threshold || context->stream_ended) {
        context->stream_ended = false;
        handle_seek(context, context->cut.in_point - elapsed);
        elapsed = context->cut.in_point;
      }
    }

    Sint32 timeout_ms = compute_event_timeout(context, elapsed);

    if (SDL_WaitEventTimeout(&event, timeout_ms)) {
      switch (event.type) {
      case SDL_EVENT_QUIT:
        if (context->cut.modified) {
          print_ffmpeg_command(context);
        }
        should_break = true;
        break;
      case SDL_EVENT_KEY_DOWN:
        should_break = handle_key_should_quit(context, &event.key);
        break;
      default:
        if (event.type == context->main_thread_event) {
          should_break = process_main_thread_commands(context);
        }
        break;
      }
    }

    if (!should_break) {
      pop_and_render_frames(context, duration);
    }
  }
  SDL_Log("Quit.");
}
