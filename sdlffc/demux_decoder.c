#include "demux_decoder.h"

// sdl
#include <SDL3/SDL_audio.h>
#include <SDL3/SDL_log.h>

// ffmpeg
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libswresample/swresample.h>

// std
#include <inttypes.h>
#include <stdbool.h>

void sdlffclib_free_video_file_ctx(SdlffVideoFileContext *ctx) {
  /* Guard each pointer independently — resources may be allocated even if
     ctx->ic is NULL (e.g. when avformat_open_input fails partway through). */
  if (ctx->frame)
    av_frame_free(&ctx->frame);
  if (ctx->audio_frame)
    av_frame_free(&ctx->audio_frame);
  if (ctx->pkt)
    av_packet_free(&ctx->pkt);
  if (ctx->swr_ctx)
    swr_free(&ctx->swr_ctx);
  if (ctx->audio_context)
    avcodec_free_context(&ctx->audio_context);
  if (ctx->video_context)
    avcodec_free_context(&ctx->video_context);
  if (ctx->ic)
    avformat_close_input(&ctx->ic);
}

void read_and_decode_next_packet(SdlffContext *context) {
  SdlffVideoFileContext *ctx = &context->video_file_ctx;
  if (ctx->flushing) return;

  if (!ctx->has_pending_pkt) {
    int result = av_read_frame(ctx->ic, ctx->pkt);
    if (result < 0) {
      SDL_Log("End of stream reached, draining decoder...");
      if (ctx->video_context) {
        avcodec_send_packet(ctx->video_context, NULL);
      }
      if (ctx->audio_context) {
        avcodec_send_packet(ctx->audio_context, NULL);
      }
      ctx->flushing = true;
      return;
    }
    if (ctx->pkt->stream_index == ctx->audio_stream && ctx->audio_context) {
      avcodec_send_packet(ctx->audio_context, ctx->pkt);
      av_packet_unref(ctx->pkt);
      while (avcodec_receive_frame(ctx->audio_context, ctx->audio_frame) >= 0) {
        if (ctx->swr_ctx && context->audio_stream) {
          int channels = ctx->audio_context->ch_layout.nb_channels > 0
                             ? ctx->audio_context->ch_layout.nb_channels
                             : 2;
          int dst_nb_samples = (int)av_rescale_rnd(
              swr_get_delay(ctx->swr_ctx, ctx->audio_context->sample_rate) +
                  ctx->audio_frame->nb_samples,
              ctx->audio_context->sample_rate, ctx->audio_context->sample_rate,
              AV_ROUND_UP);

          uint8_t *out_buf = NULL;
          int out_linesize = 0;
          if (av_samples_alloc(&out_buf, &out_linesize, channels,
                               dst_nb_samples, AV_SAMPLE_FMT_FLT, 0) >= 0) {
            int converted_samples = swr_convert(
                ctx->swr_ctx, &out_buf, dst_nb_samples,
                (const uint8_t **)(void *)ctx->audio_frame->data,
                ctx->audio_frame->nb_samples);

            if (converted_samples > 0) {
              bool drop_audio = false;
              if (ctx->seek_target_pts >= 0.0) {
                int64_t pts_raw = (ctx->audio_frame->pts != AV_NOPTS_VALUE)
                                      ? ctx->audio_frame->pts
                                      : ctx->audio_frame->best_effort_timestamp;
                if (pts_raw != AV_NOPTS_VALUE && ctx->ic && ctx->audio_stream >= 0) {
                  AVRational tb = ctx->ic->streams[ctx->audio_stream]->time_base;
                  double audio_pts_abs = (double)pts_raw * av_q2d(tb);
                  if (audio_pts_abs < ctx->seek_target_pts - 0.1) {
                    drop_audio = true;
                  }
                } else {
                  drop_audio = true;
                }
              }
              if (!drop_audio) {
                int data_size = converted_samples * channels * (int)sizeof(float);
                SDL_PutAudioStreamData(context->audio_stream, out_buf, data_size);
              }
            }
            av_freep(&out_buf);
          }
        }
        av_frame_unref(ctx->audio_frame);
      }
      return;
    }
    if (ctx->pkt->stream_index != ctx->video_stream) {
      av_packet_unref(ctx->pkt);
      return;
    }
    ctx->has_pending_pkt = true;
  }

  if (ctx->has_pending_pkt && ctx->video_context) {
    int ret = avcodec_send_packet(ctx->video_context, ctx->pkt);
    if (ret == AVERROR(EAGAIN)) {
      /* Decoder full, keep pending packet to try again after receive_frame */
      return;
    }
    av_packet_unref(ctx->pkt);
    ctx->has_pending_pkt = false;
  }
}

/// based on OpenVideoStream from testffmpeg.c
static AVCodecContext *open_video_stream(AVFormatContext *ic, int stream,
                                         const AVCodec *codec) {
  AVStream *st = ic->streams[stream];
  AVCodecParameters *codecpar = st->codecpar;
  AVCodecContext *context;
  int result;

  SDL_Log("Video stream: %s %dx%d", avcodec_get_name(codec->id),
          codecpar->width, codecpar->height);

  context = avcodec_alloc_context3(NULL);
  if (!context) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "avcodec_alloc_context3 failed");
    return NULL;
  }

  result =
      avcodec_parameters_to_context(context, ic->streams[stream]->codecpar);
  if (result < 0) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                 "avcodec_parameters_to_context failed: %s",
                 av_err2str(result));
    avcodec_free_context(&context);
    return NULL;
  }
  context->pkt_timebase = ic->streams[stream]->time_base;

  result = avcodec_open2(context, codec, NULL);
  if (result < 0) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Couldn't open codec %s: %s",
                 avcodec_get_name(context->codec_id), av_err2str(result));
    avcodec_free_context(&context);
    return NULL;
  }

  SDL_Log("video w*h = %d x %d", codecpar->width, codecpar->height);

  return context;
}

static AVCodecContext *open_audio_stream(AVFormatContext *ic, int stream,
                                         const AVCodec *codec) {
  AVStream *st = ic->streams[stream];
  AVCodecParameters *codecpar = st->codecpar;
  AVCodecContext *context;
  int result;

  SDL_Log("Audio stream: %s %d Hz, %d channels", avcodec_get_name(codec->id),
          codecpar->sample_rate, codecpar->ch_layout.nb_channels);

  context = avcodec_alloc_context3(NULL);
  if (!context) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "avcodec_alloc_context3 failed for audio");
    return NULL;
  }

  result = avcodec_parameters_to_context(context, codecpar);
  if (result < 0) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                 "avcodec_parameters_to_context failed for audio: %s",
                 av_err2str(result));
    avcodec_free_context(&context);
    return NULL;
  }
  context->pkt_timebase = st->time_base;

  result = avcodec_open2(context, codec, NULL);
  if (result < 0) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Couldn't open audio codec %s: %s",
                 avcodec_get_name(context->codec_id), av_err2str(result));
    avcodec_free_context(&context);
    return NULL;
  }

  return context;
}

bool sdlffclib_open_video(SdlffContext *context, const char *file_path) {
  SdlffVideoFileContext *ctx = &context->video_file_ctx;
  ctx->ic = NULL;
  int result = avformat_open_input(&ctx->ic, file_path, NULL, NULL);
  if (result < 0) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Couldn't open %s: %d",
                 file_path, result);
    return false;
  }
  result = avformat_find_stream_info(ctx->ic, NULL);
  if (result < 0) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Couldn't find stream info %s: %d",
                 file_path, result);
    sdlffclib_free_video_file_ctx(ctx);
    return false;
  }
  ctx->video_stream = av_find_best_stream(ctx->ic, AVMEDIA_TYPE_VIDEO, -1, -1,
                                          &ctx->video_codec, 0);
  if (ctx->video_stream < 0) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Couldn't find video stream %s",
                 file_path);
    sdlffclib_free_video_file_ctx(ctx);
    return false;
  }

  ctx->video_context =
      open_video_stream(ctx->ic, ctx->video_stream, ctx->video_codec);
  if (!ctx->video_context) {
    sdlffclib_free_video_file_ctx(ctx);
    return false;
  }

  ctx->audio_stream = av_find_best_stream(ctx->ic, AVMEDIA_TYPE_AUDIO, -1, -1,
                                          &ctx->audio_codec, 0);
  if (ctx->audio_stream >= 0) {
    ctx->audio_context =
        open_audio_stream(ctx->ic, ctx->audio_stream, ctx->audio_codec);
    if (ctx->audio_context) {
      SDL_AudioSpec src_spec;
      SDL_zero(src_spec);
      src_spec.format = SDL_AUDIO_F32;
      src_spec.channels = ctx->audio_context->ch_layout.nb_channels > 0
                              ? ctx->audio_context->ch_layout.nb_channels
                              : 2;
      src_spec.freq = ctx->audio_context->sample_rate;

      context->audio_stream = SDL_OpenAudioDeviceStream(
          SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &src_spec, NULL, NULL);
      if (context->audio_stream) {
        SDL_ResumeAudioStreamDevice(context->audio_stream);
      } else {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Failed to open audio device stream: %s", SDL_GetError());
      }

      AVChannelLayout out_ch_layout;
      av_channel_layout_default(&out_ch_layout, src_spec.channels);
      int swr_res = swr_alloc_set_opts2(
          &ctx->swr_ctx, &out_ch_layout, AV_SAMPLE_FMT_FLT, src_spec.freq,
          &ctx->audio_context->ch_layout, ctx->audio_context->sample_fmt,
          ctx->audio_context->sample_rate, 0, NULL);
      if (swr_res < 0 || swr_init(ctx->swr_ctx) < 0) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Failed to initialize SwrContext");
      }
      av_channel_layout_uninit(&out_ch_layout);
    }
  }

  // reused packet data from demuxer (video/audio)
  ctx->pkt = av_packet_alloc();
  if (!ctx->pkt) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "av_packet_alloc failed");
    sdlffclib_free_video_file_ctx(ctx);
    return false;
  }
  // reused raw decompressed video frame
  ctx->frame = av_frame_alloc();
  if (!ctx->frame) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "av_frame_alloc failed");
    sdlffclib_free_video_file_ctx(ctx);
    return false;
  }
  // reused raw decompressed audio frame
  ctx->audio_frame = av_frame_alloc();
  if (!ctx->audio_frame) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "av_frame_alloc failed for audio");
    sdlffclib_free_video_file_ctx(ctx);
    return false;
  }
  ctx->first_pts = -1.0;
  ctx->seek_target_pts = -1.0;
  ctx->has_pending_pkt = false;
  return true;
}

bool sdlffclib_fileinfo(const char *file_path) {
  AVFormatContext *ic = NULL;
  int result = avformat_open_input(&ic, file_path, NULL, NULL);
  if (result < 0) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Couldn't open %s: %d",
                 file_path, result);
    return false;
  }
  result = avformat_find_stream_info(ic, NULL);
  if (result < 0) {
    avformat_close_input(&ic);
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                 "Couldn't read stream info %s: %d", file_path, result);
    return false;
  }
  SDL_Log("Long name: %s", ic->iformat->long_name);
  SDL_Log("Name: %s", ic->iformat->name);
  SDL_Log("Mime: %s", ic->iformat->mime_type);
  SDL_Log("Extensions: %s", ic->iformat->extensions);
  SDL_Log("Streams: %u", ic->nb_streams);
  for (unsigned i = 0; i < ic->nb_streams; ++i) {
    SDL_Log("Stream: %u", i);
    AVStream *stream = ic->streams[i];
    SDL_Log("Time base: %d/%d", stream->time_base.num, stream->time_base.den);
    SDL_Log("Duration: %" PRId64, stream->duration);
    double duration = (double)(stream->duration * stream->time_base.num) /
                      stream->time_base.den;
    SDL_Log("Duration on time base: %f", duration);
    SDL_Log("Frame rate: %d/%d", stream->r_frame_rate.num,
            stream->r_frame_rate.den);
    const enum AVMediaType media_type = stream->codecpar->codec_type;
    SDL_Log("Codec type: %d, %s", media_type,
            media_type == AVMEDIA_TYPE_AUDIO   ? "audio"
            : media_type == AVMEDIA_TYPE_VIDEO ? "video"
                                               : "other");
  }

  avformat_close_input(&ic);
  return true;
}
