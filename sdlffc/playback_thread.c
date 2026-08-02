#include "playback_thread.h"
#include "demux_decoder.h"

// sdl
#include <SDL3/SDL_events.h>
#include <SDL3/SDL_log.h>

// std
#include <inttypes.h>
#include <string.h>

void send_main_thread_event(SdlffContext *context) {
  SDL_Event event;
  memset(&event, 0, sizeof(event));
  event.type = context->main_thread_event;
  SDL_PushEvent(&event);
}

static void process_video_thread_commands(SdlffContext *context) {
  SdlffVideoFileContext *ctx = &context->video_file_ctx;

  if (mailbox_receive_and_lock(&context->video_thread_mailbox, 0)) {
    const VideoThreadMsg msg = context->video_thread_mailbox_data;
    mailbox_unlock(&context->video_thread_mailbox);

    if (msg.command == VTC_SEEK) {
      SDL_Log("[SEEK LOG] video thread received VTC_SEEK target=%.2f sec", msg.seek_target_sec);
      if (ctx->video_stream >= 0 && ctx->ic) {
        AVRational tb = ctx->ic->streams[ctx->video_stream]->time_base;
        double first = (ctx->first_pts >= 0.0) ? ctx->first_pts : 0.0;
        double target_pts = first + msg.seek_target_sec;
        int64_t seek_ts = (int64_t)(target_pts / av_q2d(tb));

        if (ctx->has_pending_pkt) {
          av_packet_unref(ctx->pkt);
          ctx->has_pending_pkt = false;
        }

        frame_queue_flush(&context->frame_queue);
        int seek_res = av_seek_frame(ctx->ic, ctx->video_stream, seek_ts, AVSEEK_FLAG_BACKWARD);
        SDL_Log("[SEEK LOG] av_seek_frame(stream=%d, ts=%" PRId64 ") returned %d", ctx->video_stream, seek_ts, seek_res);
        if (seek_res < 0) {
          int64_t seek_ts_global = (int64_t)(target_pts * AV_TIME_BASE);
          int seek_res2 = av_seek_frame(ctx->ic, -1, seek_ts_global, AVSEEK_FLAG_BACKWARD);
          SDL_Log("[SEEK LOG] av_seek_frame(global, ts=%" PRId64 ") returned %d", seek_ts_global, seek_res2);
        }
        if (ctx->video_context) {
          avcodec_flush_buffers(ctx->video_context);
        }
        if (ctx->audio_context) {
          avcodec_flush_buffers(ctx->audio_context);
        }
        ctx->flushing = false;
        ctx->seek_target_pts = target_pts;
        SDL_Log("[SEEK LOG] seek setup complete. seek_target_pts=%.2f", target_pts);
      }
    }
  }
}

int SDLCALL video_thread_cb(void *data) {
  SdlffContext *context = (SdlffContext *)data;
  SDL_Log("video thread started.");

  /* Wait for VTC_PLAY, polling quit_requested every 100 ms so that
     sdlffclib_done() can shut us down before playback begins. */
  bool do_play = false;
  while (!SDL_GetAtomicInt(&context->quit_requested)) {
    const bool has_msg =
        mailbox_receive_and_lock(&context->video_thread_mailbox, 100);
    const VideoThreadMsg msg = context->video_thread_mailbox_data;
    mailbox_unlock(&context->video_thread_mailbox);
    if (has_msg && msg.command == VTC_PLAY) {
      do_play = true;
      break;
    }
  }

  if (!do_play) {
    SDL_Log("video thread exit (before play).");
    return 0;
  }
  SDL_Log("video thread play command received.");

  SdlffVideoFileContext *ctx = &context->video_file_ctx;

  while (!SDL_GetAtomicInt(&context->quit_requested)) {
    /* Check for seek command */
    process_video_thread_commands(context);

    bool decoded_frame = false;

    while (!decoded_frame && !SDL_GetAtomicInt(&context->quit_requested)) {
      process_video_thread_commands(context);
      read_and_decode_next_packet(context);

      if (ctx->video_context) {
        int ret = avcodec_receive_frame(ctx->video_context, ctx->frame);
        if (ret >= 0) {
          int64_t pts_raw = (ctx->frame->pts != AV_NOPTS_VALUE)
                                ? ctx->frame->pts
                                : ctx->frame->best_effort_timestamp;
          if (pts_raw == AV_NOPTS_VALUE) {
            pts_raw = 0;
          }
          AVRational tb = ctx->ic->streams[ctx->video_stream]->time_base;
          double frame_pts_abs = (double)pts_raw * av_q2d(tb);

          if (ctx->first_pts < 0.0) {
            ctx->first_pts = frame_pts_abs;
          }
          double pts = frame_pts_abs - ctx->first_pts;

          /* If seeking, drop pre-roll frames in video thread until near target_pts */
          if (ctx->seek_target_pts >= 0.0) {
            if (frame_pts_abs < ctx->seek_target_pts - 0.1) {
              SDL_Log("[SEEK LOG] dropping pre-roll frame pts_abs=%.2f target=%.2f", frame_pts_abs, ctx->seek_target_pts);
              av_frame_unref(ctx->frame);
              continue;
            }
            SDL_Log("[SEEK LOG] reached target frame pts_abs=%.2f target=%.2f", frame_pts_abs, ctx->seek_target_pts);
            ctx->seek_target_pts = -1.0;
          }

          decoded_frame = true;

          /* Ref the frame for queue ownership; avcodec may reuse ctx->frame */
          AVFrame *qframe = av_frame_alloc();
          if (qframe && av_frame_ref(qframe, ctx->frame) >= 0) {
            if (!frame_queue_push(&context->frame_queue, qframe, pts,
                                  &context->quit_requested)) {
              /* Push aborted: quit_requested was set while we waited */
              av_frame_unref(qframe);
              av_frame_free(&qframe);
            }
          } else {
            av_frame_free(&qframe);
            SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                         "av_frame_alloc/ref failed");
          }
          av_frame_unref(ctx->frame);
        } else if (ret == AVERROR_EOF || (ctx->flushing && ret == AVERROR(EAGAIN))) {
          /* Decoder is fully drained or requires no more input */
          ctx->seek_target_pts = -1.0;
          break;
        }
      }
    }

    if (SDL_GetAtomicInt(&context->quit_requested)) {
      break;
    }

    if (ctx->flushing && !decoded_frame) {
      /* All frames pushed; tell main thread the stream is finished */
      MainThreadCommand mtc = MTC_VIDEO_END;
      mailbox_send_overwrite(&context->main_thread_mailbox, &mtc, sizeof(mtc));
      send_main_thread_event(context);
      break;
    }
  }

  SDL_Log("video thread exit.");
  return 0;
}
