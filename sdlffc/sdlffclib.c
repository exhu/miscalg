#include "sdlffclib.h"

// video decoding is based on testffmpeg.c from libsdl repository.

// sdl
#include "SDL3/SDL_keyboard.h"
#include "SDL3/SDL_keycode.h"
#include "SDL3/SDL_oldnames.h"
#include "SDL3/SDL_timer.h"
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
#include <libavutil/mastering_display_metadata.h>
#include <libavutil/pixdesc.h>
#include <libswscale/swscale.h>

// std
#include <memory.h>
#include <stdbool.h>
#include <string.h>

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

  context->main_thread_event = SDL_RegisterEvents(1);

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

static bool is_video_finished(SdlffContext *context) {
  return context->video_file_ctx.flushing || (context->video_file_ctx.ic == NULL);
}

void sdlffclib_done(SdlffContext **out_context) {
  SdlffContext *context = *out_context;

  sdlffclib_free_video_file_ctx(&context->video_file_ctx);

  /// free sdl resources
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

static SDL_Colorspace get_frame_colorspace(AVFrame *frame) {
  SDL_Colorspace colorspace = SDL_COLORSPACE_SRGB;

  if (frame && frame->colorspace != AVCOL_SPC_RGB) {
#ifdef DEBUG_COLORSPACE
    SDL_Log("Frame colorspace: range: %d, primaries: %d, trc: %d, colorspace: "
            "%d, chroma_location: %d",
            frame->color_range, frame->color_primaries, frame->color_trc,
            frame->colorspace, frame->chroma_location);
#endif
    colorspace = SDL_DEFINE_COLORSPACE(
        SDL_COLOR_TYPE_YCBCR, frame->color_range, frame->color_primaries,
        frame->color_trc, frame->colorspace, frame->chroma_location);
  }
  return colorspace;
}

static SDL_PropertiesID create_video_texture_properties(AVFrame *frame,
                                                        SDL_PixelFormat format,
                                                        int access) {
  AVFrameSideData *pSideData;
  SDL_PropertiesID props;
  int width = frame->width;
  int height = frame->height;
  SDL_Colorspace colorspace = get_frame_colorspace(frame);

  /* ITU-R BT.2408-6 recommends using an SDR white point of 203 nits, which is
   * more likely for game content */
  static const float k_flSDRWhitePoint = 203.0f;
  float flMaxLuminance = k_flSDRWhitePoint;

// TODO hardware decoding
#if 0
    if (frame->hw_frames_ctx) {
        AVHWFramesContext *frames = (AVHWFramesContext *)(frame->hw_frames_ctx->data);

        width = frames->width;
        height = frames->height;
        if (format == SDL_PIXELFORMAT_UNKNOWN) {
            format = GetTextureFormat(frames->sw_format);
        }
    } else {
#endif
  if (format == SDL_PIXELFORMAT_UNKNOWN) {
    format = get_texture_format(frame->format);
  }
  //}

  props = SDL_CreateProperties();
  SDL_SetNumberProperty(props, SDL_PROP_TEXTURE_CREATE_COLORSPACE_NUMBER,
                        colorspace);
  pSideData =
      av_frame_get_side_data(frame, AV_FRAME_DATA_MASTERING_DISPLAY_METADATA);
  if (pSideData) {
    AVMasteringDisplayMetadata *pMasteringDisplayMetadata =
        (AVMasteringDisplayMetadata *)pSideData->data;
    flMaxLuminance = (float)pMasteringDisplayMetadata->max_luminance.num /
                     pMasteringDisplayMetadata->max_luminance.den;
  } else if (SDL_COLORSPACETRANSFER(colorspace) ==
             SDL_TRANSFER_CHARACTERISTICS_PQ) {
    /* The official definition is 10000, but PQ game content is often mastered
     * for 400 or 1000 nits */
    flMaxLuminance = 1000.0f;
  }
  if (flMaxLuminance > k_flSDRWhitePoint) {
    SDL_SetFloatProperty(props, SDL_PROP_TEXTURE_CREATE_SDR_WHITE_POINT_FLOAT,
                         k_flSDRWhitePoint);
    SDL_SetFloatProperty(props, SDL_PROP_TEXTURE_CREATE_HDR_HEADROOM_FLOAT,
                         flMaxLuminance / k_flSDRWhitePoint);
  }
  SDL_SetNumberProperty(props, SDL_PROP_TEXTURE_CREATE_FORMAT_NUMBER, format);
  SDL_SetNumberProperty(props, SDL_PROP_TEXTURE_CREATE_ACCESS_NUMBER, access);
  SDL_SetNumberProperty(props, SDL_PROP_TEXTURE_CREATE_WIDTH_NUMBER, width);
  SDL_SetNumberProperty(props, SDL_PROP_TEXTURE_CREATE_HEIGHT_NUMBER, height);

  return props;
}

static const char *SWS_CONTEXT_CONTAINER_PROPERTY = "SWS_CONTEXT_CONTAINER";
struct SwsContextContainer
{
    struct SwsContext *context;
};

static void SDLCALL FreeSwsContextContainer(void *userdata, void *value)
{
    struct SwsContextContainer *sws_container = (struct SwsContextContainer *)value;
    if (sws_container->context) {
        sws_freeContext(sws_container->context);
    }
    SDL_free(sws_container);
}

static bool get_texture_for_memory_frame(SdlffContext *context, AVFrame *frame,
                                         SDL_Texture **texture) {
  int texture_width = 0, texture_height = 0;
  SDL_PixelFormat texture_format = SDL_PIXELFORMAT_UNKNOWN;
  SDL_PixelFormat frame_format = get_texture_format(frame->format);

  if (*texture) {
    SDL_PropertiesID props = SDL_GetTextureProperties(*texture);
    texture_format = (SDL_PixelFormat)SDL_GetNumberProperty(
        props, SDL_PROP_TEXTURE_FORMAT_NUMBER, SDL_PIXELFORMAT_UNKNOWN);
    texture_width =
        (int)SDL_GetNumberProperty(props, SDL_PROP_TEXTURE_WIDTH_NUMBER, 0);
    texture_height =
        (int)SDL_GetNumberProperty(props, SDL_PROP_TEXTURE_HEIGHT_NUMBER, 0);
  }
  if (!*texture || texture_width != frame->width ||
      texture_height != frame->height ||
      (frame_format != SDL_PIXELFORMAT_UNKNOWN &&
       texture_format != frame_format) ||
      (frame_format == SDL_PIXELFORMAT_UNKNOWN &&
       texture_format != SDL_PIXELFORMAT_ARGB8888)) {
    if (*texture) {
      SDL_DestroyTexture(*texture);
    }

    SDL_PropertiesID props;
    if (frame_format == SDL_PIXELFORMAT_UNKNOWN) {
      props = create_video_texture_properties(frame, SDL_PIXELFORMAT_ARGB8888,
                                           SDL_TEXTUREACCESS_STREAMING);
    } else {
      props = create_video_texture_properties(frame, frame_format,
                                           SDL_TEXTUREACCESS_STREAMING);
    }
    *texture = SDL_CreateTextureWithProperties(context->renderer, props);
    SDL_DestroyProperties(props);
    if (!*texture) {
      return false;
    }

    if (frame_format == SDL_PIXELFORMAT_UNKNOWN ||
        SDL_ISPIXELFORMAT_ALPHA(frame_format)) {
      SDL_SetTextureBlendMode(*texture, SDL_BLENDMODE_BLEND);
    } else {
      SDL_SetTextureBlendMode(*texture, SDL_BLENDMODE_NONE);
    }
    SDL_SetTextureScaleMode(*texture, SDL_SCALEMODE_LINEAR);
  }

  switch (frame_format) {
  case SDL_PIXELFORMAT_UNKNOWN: {
    SDL_PropertiesID props = SDL_GetTextureProperties(*texture);
    struct SwsContextContainer *sws_container =
        (struct SwsContextContainer *)SDL_GetPointerProperty(
            props, SWS_CONTEXT_CONTAINER_PROPERTY, NULL);
    if (!sws_container) {
      sws_container =
          (struct SwsContextContainer *)SDL_calloc(1, sizeof(*sws_container));
      if (!sws_container) {
        return false;
      }
      SDL_SetPointerPropertyWithCleanup(props, SWS_CONTEXT_CONTAINER_PROPERTY,
                                        sws_container, FreeSwsContextContainer,
                                        NULL);
    }
    sws_container->context = sws_getCachedContext(
        sws_container->context, frame->width, frame->height, frame->format,
        frame->width, frame->height, AV_PIX_FMT_BGRA, SWS_POINT, NULL, NULL,
        NULL);
    if (sws_container->context) {
      uint8_t *pixels[4];
      int pitch[4];
      if (SDL_LockTexture(*texture, NULL, (void **)&pixels[0], &pitch[0])) {
        sws_scale(sws_container->context, (const uint8_t *const *)frame->data,
                  frame->linesize, 0, frame->height, pixels, pitch);
        SDL_UnlockTexture(*texture);
      }
    } else {
      SDL_SetError("Can't initialize the conversion context");
      return false;
    }
    break;
  }
  case SDL_PIXELFORMAT_IYUV:
    if (frame->linesize[0] > 0 && frame->linesize[1] > 0 &&
        frame->linesize[2] > 0) {
      SDL_UpdateYUVTexture(*texture, NULL, frame->data[0], frame->linesize[0],
                           frame->data[1], frame->linesize[1], frame->data[2],
                           frame->linesize[2]);
    } else if (frame->linesize[0] < 0 && frame->linesize[1] < 0 &&
               frame->linesize[2] < 0) {
      SDL_UpdateYUVTexture(
          *texture, NULL,
          frame->data[0] + frame->linesize[0] * (frame->height - 1),
          -frame->linesize[0],
          frame->data[1] +
              frame->linesize[1] * (AV_CEIL_RSHIFT(frame->height, 1) - 1),
          -frame->linesize[1],
          frame->data[2] +
              frame->linesize[2] * (AV_CEIL_RSHIFT(frame->height, 1) - 1),
          -frame->linesize[2]);
    }
    break;
  default:
    if (frame->linesize[0] < 0) {
      SDL_UpdateTexture(*texture, NULL,
                        frame->data[0] +
                            frame->linesize[0] * (frame->height - 1),
                        -frame->linesize[0]);
    } else {
      SDL_UpdateTexture(*texture, NULL, frame->data[0], frame->linesize[0]);
    }
    break;
  }
  return true;
}

static bool get_texture_for_video_frame(SdlffContext *context, AVFrame *frame,
                                        SDL_Texture **texture) {
  // TODO hw accel formats
  return get_texture_for_memory_frame(context, frame, texture);
}

// TODO do we need frame here?
static void display_video_frame(SdlffContext *context, AVFrame *frame) {
  /* Update the video texture */
  if (!get_texture_for_video_frame(context, frame, &context->video_texture)) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                 "Couldn't get texture for frame: %s", SDL_GetError());
    return;
  }

  SDL_FRect src;
  src.x = 0.0f;
  src.y = 0.0f;
  src.w = (float)frame->width;
  src.h = (float)frame->height;
  if (frame->linesize[0] < 0) {
    SDL_RenderTextureRotated(context->renderer, context->video_texture, &src,
                             NULL, 0.0, NULL, SDL_FLIP_VERTICAL);
  } else {
    SDL_RenderTexture(context->renderer, context->video_texture, &src, NULL);
  }
}

// TODO do we need frame here?
static void handle_video_frame(SdlffContext *context, AVFrame *frame,
                               double pts) {
#if 0
    /* Quick and dirty PTS handling */
    if (!video_start) {
        video_start = SDL_GetTicks();
    }
    double now = (double)(SDL_GetTicks() - video_start) / 1000.0;
    if (now < pts) {
        SDL_DelayPrecise((Uint64)((pts - now) * SDL_NS_PER_SECOND));
    }
#endif

  SDL_SetRenderDrawColor(context->renderer, 0, 0, 0, 255);
  SDL_RenderClear(context->renderer);
  display_video_frame(context, frame);
  SDL_RenderPresent(context->renderer);
}

// true to continue
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

      handle_video_frame(context, ctx->frame, pts);
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
  return !ctx->flushing;
}

static const Uint32 default_timer_interval = 1000/240;

static Uint32 SDLCALL timer_cb(void *userdata, SDL_TimerID timerID,
                                   Uint32 interval) {
  SdlffContext *context = (SdlffContext *)userdata;
  if (!is_video_finished(context)) {
    SDL_Event event;
    memset(&event, 0, sizeof(event));
    event.type = context->main_thread_event;
    SDL_PushEvent(&event);
  }

  return default_timer_interval;
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

  context->timer_id = SDL_AddTimer(default_timer_interval, &timer_cb, context);

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
    default:
      if (event.type == context->main_thread_event) {
        process_next_file_frame(context);
      }
      break;
    }
  }
  SDL_StopTextInput(context->window);
  SDL_RemoveTimer(context->timer_id);
  SDL_Log("Quit.");
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
