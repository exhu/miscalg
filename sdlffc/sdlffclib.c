#include "sdlffclib.h"
// sdl
#include "SDL3/SDL_keyboard.h"
#include "SDL3/SDL_keycode.h"
#include "sdlffclib_private.h"
#include <SDL3/SDL_dialog.h>
#include <SDL3/SDL_events.h>
#include <SDL3/SDL_hints.h>
#include <SDL3/SDL_init.h>
#include <SDL3/SDL_pixels.h>
#include <SDL3/SDL_render.h>
#include <SDL3/SDL_video.h>

// ffmpeg
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
// #include <libavutil/mastering_display_metadata.h>
#include <libavutil/pixdesc.h>
// #include <libswscale/swscale.h>

// std
#include <memory.h>
#include <stdbool.h>

bool sdlffclib_init(SdlffContext **out_context) {
  static SdlffContext global_context = {0};
  // memset(&global_context, 0, sizeof(SdlffContext));

  SDL_SetAppMetadata("rdlffc", "0.1", "com.github.exhu.miscalg.sdlffc");

  if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO)) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Failed to init: %s",
                 SDL_GetError());
    return false;
  }

  SdlffContext *context = &global_context;
  *out_context = context;

  if (!SDL_CreateWindowAndRenderer("hello sdl!", 1280, 720,
                                   SDL_WINDOW_RESIZABLE, &context->window,
                                   &context->renderer)) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                 "Failed to create window and renderer: %s", SDL_GetError());
    return false;
  }
  SDL_SetWindowMinimumSize(context->window, 320, 240);
  SDL_SetRenderVSync(context->renderer, SDL_RENDERER_VSYNC_ADAPTIVE);
  SDL_ShowWindow(context->window);

  // TODO move create streaming texture for video somewhere else
  context->streaming_texture =
      SDL_CreateTexture(context->renderer, SDL_PIXELFORMAT_YV12,
                        SDL_TEXTUREACCESS_STREAMING, 320, 240);

  if (context->streaming_texture == NULL) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Failed to create texture: %s",
                 SDL_GetError());
  }
  // TODO https://github.com/libsdl-org/SDL/blob/main/test/testffmpeg.c
  return true;
}

/// free ffmpeg resources
static void sdlffclib_free_video_file_ctx(SdlffVideoFileContext *ctx) {
  if (ctx->ic) {
    if (ctx->frame)
      av_frame_free(&ctx->frame);
    if (ctx->pkt)
      av_packet_free(&ctx->pkt);
    if (ctx->audio_context)
      avcodec_free_context(&ctx->audio_context);
    if (ctx->video_context)
      avcodec_free_context(&ctx->video_context);
    if (ctx->ic)
      avformat_close_input(&ctx->ic);
  }
}

void sdlffclib_done(SdlffContext **out_context) {
  SdlffContext *context = *out_context;

  sdlffclib_free_video_file_ctx(&context->video_file_ctx);

  /// free sdl resources
  SDL_DestroyTexture(context->streaming_texture);
  SDL_DestroyRenderer(context->renderer);
  SDL_DestroyWindow(context->window);
  memset(*out_context, 0, sizeof(SdlffContext));
  *out_context = NULL;
  SDL_Quit();
}

static void sdlffclib_render(SdlffContext *context) {
  SDL_SetRenderDrawColor(context->renderer, 0x00, 0x00, 0x00, 0x00);
  SDL_RenderClear(context->renderer);
  SDL_SetRenderDrawColor(context->renderer, 0xFF, 0x00, 0x00, 0xFF);
  SDL_RenderLine(context->renderer, 0.f, 0.f, 50.f, 25.f);

  SDL_RenderPresent(context->renderer);
}

#if 0
static void dialog_cb(void *userdata, const char * const *filelist, int filter) {
  if (filelist != NULL) {
    SDL_Log("Selected '%s'", filelist[0]);
  } else {
    SDL_Log("Error.");
  }
}
#endif

/// return true to quit
static bool handle_key_should_quit(const SDL_KeyboardEvent *key) {
  switch (key->key) {
  case SDLK_Q:
    return true;
    break;
  default:;
  }
  return false;
}

static bool process_next_file_frame(SdlffContext *context) {
  int result;
  SdlffVideoFileContext *ctx = &context->video_file_ctx;
  if (!ctx->flushing) {
    result = av_read_frame(ctx->ic, ctx->pkt);
    if (result < 0) {
      SDL_Log("End of stream, finishing decode");
      if (ctx->audio_context) {
        avcodec_flush_buffers(ctx->audio_context);
      }
      if (ctx->video_context) {
        avcodec_flush_buffers(ctx->video_context);
      }
      ctx->flushing = true;
    } else {
      // TODO handle audio
#if 0
      if (ctx->pkt->stream_index == ctx->audio_stream) {
                    result = avcodec_send_packet(ctx->audio_context, ctx->pkt);
                    if (result < 0) {
                        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "avcodec_send_packet(audio_context) failed: %s", av_err2str(result));
                    }
      } else
#endif
      if (ctx->pkt->stream_index == ctx->video_stream) {
        result = avcodec_send_packet(ctx->video_context, ctx->pkt);
        if (result < 0) {
          SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                       "avcodec_send_packet(video_context) failed: %s",
                       av_err2str(result));
        }
      }
      av_packet_unref(ctx->pkt);
    }
  }
  // TODO handle audio
  bool decoded = false;
  if (ctx->video_context) {
    while (avcodec_receive_frame(ctx->video_context, ctx->frame) >= 0) {
      double pts =
          ((double)ctx->frame->pts * ctx->video_context->pkt_timebase.num) /
          ctx->video_context->pkt_timebase.den;
      if (ctx->first_pts < 0.0) {
        ctx->first_pts = pts;
      }
      pts -= ctx->first_pts;

      // TODO
      // HandleVideoFrame(ctx->frame, pts);
      decoded = true;
    }
  }
  if (ctx->flushing && !decoded) {
// TODO
#if 0
    if (SDL_GetAudioStreamQueued(audio) > 0) {
        /* Wait a little bit for the audio to finish */
        SDL_Delay(10);
    } else {
        done = true;
    }
#endif
  }
  return ctx->flushing;
}

void sdlffclib_main_loop(SdlffContext *context) {
  // SDL_ShowOpenFileDialog(dialog_cb, NULL, context->window, NULL, 0, NULL,
  // false);
  SDL_Event event;
  bool should_break = false;

  SDL_Rect area = {0, 0, 200, 30};
  int cursor = 0;
  // SDL_SetTextInputArea(context->window, &area, cursor);
  // SDL_StartTextInput(context->window);

  while (!should_break && SDL_WaitEvent(&event)) {
    switch (event.type) {
    case SDL_EVENT_QUIT:
      should_break = true;
      break;
    case SDL_EVENT_WINDOW_EXPOSED:
      sdlffclib_render(context);
      break;
    case SDL_EVENT_KEY_DOWN:
      should_break = handle_key_should_quit(&event.key);
      SDL_Log("key down: %s, repeat %d", SDL_GetKeyName(event.key.key),
              event.key.repeat);
      break;
    case SDL_EVENT_TEXT_INPUT:
      SDL_Log("text input: %s", event.text.text);
      break;

    default:;
    }
  }
  SDL_StopTextInput(context->window);
  SDL_Log("Quit.");
}

/// copied GetTextureFormat from testffmpeg.c
static SDL_PixelFormat get_texture_format(enum AVPixelFormat format) {
  switch (format) {
  case AV_PIX_FMT_RGB8:
    return SDL_PIXELFORMAT_RGB332;
  case AV_PIX_FMT_RGB444:
    return SDL_PIXELFORMAT_XRGB4444;
  case AV_PIX_FMT_RGB555:
    return SDL_PIXELFORMAT_XRGB1555;
  case AV_PIX_FMT_BGR555:
    return SDL_PIXELFORMAT_XBGR1555;
  case AV_PIX_FMT_RGB565:
    return SDL_PIXELFORMAT_RGB565;
  case AV_PIX_FMT_BGR565:
    return SDL_PIXELFORMAT_BGR565;
  case AV_PIX_FMT_RGB24:
    return SDL_PIXELFORMAT_RGB24;
  case AV_PIX_FMT_BGR24:
    return SDL_PIXELFORMAT_BGR24;
  case AV_PIX_FMT_0RGB32:
    return SDL_PIXELFORMAT_XRGB8888;
  case AV_PIX_FMT_0BGR32:
    return SDL_PIXELFORMAT_XBGR8888;
  case AV_PIX_FMT_NE(RGB0, 0BGR):
    return SDL_PIXELFORMAT_RGBX8888;
  case AV_PIX_FMT_NE(BGR0, 0RGB):
    return SDL_PIXELFORMAT_BGRX8888;
  case AV_PIX_FMT_RGB32:
    return SDL_PIXELFORMAT_ARGB8888;
  case AV_PIX_FMT_RGB32_1:
    return SDL_PIXELFORMAT_RGBA8888;
  case AV_PIX_FMT_BGR32:
    return SDL_PIXELFORMAT_ABGR8888;
  case AV_PIX_FMT_BGR32_1:
    return SDL_PIXELFORMAT_BGRA8888;
  case AV_PIX_FMT_YUV420P:
    return SDL_PIXELFORMAT_IYUV;
  case AV_PIX_FMT_YUYV422:
    return SDL_PIXELFORMAT_YUY2;
  case AV_PIX_FMT_UYVY422:
    return SDL_PIXELFORMAT_UYVY;
  case AV_PIX_FMT_NV12:
    return SDL_PIXELFORMAT_NV12;
  case AV_PIX_FMT_NV21:
    return SDL_PIXELFORMAT_NV21;
  case AV_PIX_FMT_P010:
    return SDL_PIXELFORMAT_P010;
  default:
    return SDL_PIXELFORMAT_UNKNOWN;
  }
}

static bool is_pixel_format_supported(enum AVPixelFormat format) {
  return get_texture_format(format) != SDL_PIXELFORMAT_UNKNOWN;
}

/// copied from testffmpeg.c GetSupportedPixelFormat
static enum AVPixelFormat
get_supported_pixel_format_cb(AVCodecContext *s,
                              const enum AVPixelFormat *pix_fmts) {
  const enum AVPixelFormat *p;

  for (p = pix_fmts; *p != AV_PIX_FMT_NONE; p++) {
    const AVPixFmtDescriptor *desc = av_pix_fmt_desc_get(*p);

    if (!(desc->flags & AV_PIX_FMT_FLAG_HWACCEL)) {
      /* We support all memory formats using swscale */
      break;
    }

    if (is_pixel_format_supported(*p)) {
      /* We support this format */
      break;
    }
  }

  if (*p == AV_PIX_FMT_NONE) {
    SDL_Log("Couldn't find a supported pixel format:");
    for (p = pix_fmts; *p != AV_PIX_FMT_NONE; p++) {
      SDL_Log("    %s", av_get_pix_fmt_name(*p));
    }
  }

  return *p;
}
/// based on OpenVideoStream from testffmpeg.c
static AVCodecContext *open_video_stream(AVFormatContext *ic, int stream,
                                         const AVCodec *codec) {
  AVStream *st = ic->streams[stream];
  AVCodecParameters *codecpar = st->codecpar;
  AVCodecContext *context;
  const AVCodecHWConfig *config;
  int i;
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

// TODO add hw decoder support
#if 0
  /* Allow supported hardware accelerated pixel formats */
  context->get_format = get_supported_pixel_format_cb;
#endif
  // skip hw device for now, software decoder only
  result = avcodec_open2(context, codec, NULL);
  if (result < 0) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Couldn't open codec %s: %s",
                 avcodec_get_name(context->codec_id), av_err2str(result));
    avcodec_free_context(&context);
    return NULL;
  }

  // SDL_SetWindowSize(window, codecpar->width, codecpar->height);
  SDL_Log("video w*h = %d x %d", codecpar->width, codecpar->height);

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
  ctx->video_stream = av_find_best_stream(ctx->ic, AVMEDIA_TYPE_VIDEO, -1, -1,
                                          &ctx->video_codec, 0);
  if (ctx->video_stream < 0) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Couldn't find video stream %s",
                 file_path);
    return false;
  }

  ctx->video_context =
      open_video_stream(ctx->ic, ctx->video_stream, ctx->video_codec);

  // TODO audio

  // reused packet data from demuxer (video/audio)
  ctx->pkt = av_packet_alloc();
  if (!ctx->pkt) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "av_packet_alloc failed");
    return false;
  }
  // reused raw decompressed video/audio frame
  ctx->frame = av_frame_alloc();
  if (!ctx->frame) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "av_frame_alloc failed");
    return false;
  }
  ctx->first_pts = -1.0;
  if (ctx->video_context)
    return true;

  return false;
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
  SDL_Log("Streams: %d", ic->nb_streams);
  for (unsigned i = 0; i < ic->nb_streams; ++i) {
    SDL_Log("Stream: %d", i);
    AVStream *stream = ic->streams[i];
    SDL_Log("Time base: %d/%d", stream->time_base.num, stream->time_base.den);
    SDL_Log("Duration: %ld", stream->duration);
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
