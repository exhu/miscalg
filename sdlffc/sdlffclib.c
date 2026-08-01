#include "sdlffclib.h"

// video decoding is based on testffmpeg.c from libsdl repository.

// sdl
#include "SDL3/SDL_keyboard.h"
#include "SDL3/SDL_keycode.h"
#include "SDL3/SDL_thread.h"
#include "SDL3/SDL_timer.h"
#include "frame_queue.h"
#include "mailbox.h"
#include "sdlffclib_private.h"
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
#include <inttypes.h>
#include <memory.h>
#include <stdbool.h>
#include <string.h>

static bool fill_texture_with_frame_data(SDL_Texture *texture, AVFrame *frame,
                                         void *pixels, int pitch);
static bool create_or_reuse_cached_texture(SdlffContext *context, AVFrame *frame,
                                            SDL_Texture **texture);
static void render_frame_main_thread(SdlffContext *context, AVFrame *frame);

/// notify main thread to read mailbox
static void send_main_thread_event(SdlffContext *context) {
    SDL_Event event;
    memset(&event, 0, sizeof(event));
    event.type = context->main_thread_event;
    SDL_PushEvent(&event);
}

static void read_and_decode_next_packet(SdlffContext *context) {
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
}

/// video decoding thread
static int SDLCALL video_thread_cb(void *data) {
  SdlffContext *context = (SdlffContext *)data;
  SDL_Log("video thread started.");

  /* Wait for VTC_PLAY, polling quit_requested every 100 ms so that
     sdlffclib_done() can shut us down before playback begins. */
  bool do_play = false;
  while (!SDL_GetAtomicInt(&context->quit_requested)) {
    const bool has_msg =
        mailbox_receive_and_lock(&context->video_thread_mailbox, 100);
    const VideoThreadCommand cmd = context->video_thread_mailbox_data;
    mailbox_unlock(&context->video_thread_mailbox);
    if (has_msg && cmd == VTC_PLAY) {
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
        if (ctx->first_pts < 0.0) {
          ctx->first_pts = pts;
        }
        pts -= ctx->first_pts;

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
      }
    }

    if (SDL_GetAtomicInt(&context->quit_requested)) {
      break;
    }

    if (ctx->flushing && !decoded_frame) {
      /* All frames pushed; tell main thread the stream is finished */
      MainThreadCommand mtc = MTC_VIDEO_END;
      mailbox_send(&context->main_thread_mailbox, &mtc, sizeof(mtc));
      send_main_thread_event(context);
      break;
    }
  }

  SDL_Log("video thread exit.");
  return 0;
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
  *out_context = context;

  SDL_SetAtomicInt(&context->quit_requested, 0);
  frame_queue_init(&context->frame_queue);

  context->main_thread_event = SDL_RegisterEvents(1);

  if (!SDL_CreateWindowAndRenderer("hello sdl!", 1280, 720,
                                   SDL_WINDOW_RESIZABLE, &context->window,
                                   &context->renderer)) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                 "Failed to create window and renderer: %s", SDL_GetError());
    return false;
  }

  mailbox_init(&context->main_thread_mailbox,
               &context->main_thread_mailbox_data,
               sizeof(context->main_thread_mailbox_data));
  mailbox_init(&context->video_thread_mailbox,
               &context->video_thread_mailbox_data,
               sizeof(context->video_thread_mailbox_data));  // FIXED: was sizeof(main_thread_mailbox_data)

  context->video_thread =
      SDL_CreateThread(&video_thread_cb, "video-thread", context);
  SDL_SetWindowMinimumSize(context->window, 320, 240);
  if (!SDL_SetRenderVSync(context->renderer, SDL_RENDERER_VSYNC_ADAPTIVE)) {
    SDL_SetRenderVSync(context->renderer, 1);
  }
  SDL_ShowWindow(context->window);
  return true;
}

/// free ffmpeg resources
static void sdlffclib_free_video_file_ctx(SdlffVideoFileContext *ctx) {
  /* Guard each pointer independently — resources may be allocated even if
     ctx->ic is NULL (e.g. when avformat_open_input fails partway through). */
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

void sdlffclib_done(SdlffContext **out_context) {
  SdlffContext *context = *out_context;

  /* Signal video thread to stop and unblock it if blocked in frame_queue_push */
  SDL_SetAtomicInt(&context->quit_requested, 1);
  frame_queue_flush(&context->frame_queue);
  SDL_WaitThread(context->video_thread, NULL);

  mailbox_done(&context->main_thread_mailbox);
  mailbox_done(&context->video_thread_mailbox);
  frame_queue_done(&context->frame_queue);

  sdlffclib_free_video_file_ctx(&context->video_file_ctx);

  /// free sdl resources
  SDL_DestroyRenderer(context->renderer);
  SDL_DestroyWindow(context->window);
  memset(*out_context, 0, sizeof(SdlffContext));
  *out_context = NULL;
  SDL_Quit();
}

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

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wswitch-enum"
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
#pragma GCC diagnostic pop

static SDL_Colorspace get_frame_colorspace(AVFrame *frame) {
  SDL_Colorspace colorspace = SDL_COLORSPACE_SRGB;

  if (frame && frame->colorspace != AVCOL_SPC_RGB) {
#ifdef DEBUG_COLORSPACE
    SDL_Log("Frame colorspace: range: %d, primaries: %d, trc: %d, colorspace: "
            "%d, chroma_location: %d",
            frame->color_range, frame->color_primaries, frame->color_trc,
            frame->colorspace, frame->chroma_location);
#endif
    colorspace = (SDL_Colorspace)SDL_DEFINE_COLORSPACE(
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

  if (format == SDL_PIXELFORMAT_UNKNOWN) {
    format = get_texture_format((enum AVPixelFormat)frame->format);
  }
  if (SDL_COLORSPACETYPE(colorspace) != SDL_COLOR_TYPE_RGB &&
      (format == SDL_PIXELFORMAT_ARGB8888 || format == SDL_PIXELFORMAT_RGBA8888 ||
       format == SDL_PIXELFORMAT_BGRA8888 || format == SDL_PIXELFORMAT_ABGR8888)) {
    colorspace = SDL_COLORSPACE_SRGB;
  }

  props = SDL_CreateProperties();
  SDL_SetNumberProperty(props, SDL_PROP_TEXTURE_CREATE_COLORSPACE_NUMBER,
                        colorspace);
  pSideData =
      av_frame_get_side_data(frame, AV_FRAME_DATA_MASTERING_DISPLAY_METADATA);
  if (pSideData) {
    AVMasteringDisplayMetadata *pMasteringDisplayMetadata =
        (AVMasteringDisplayMetadata *)(void *)pSideData->data;
    flMaxLuminance = (float)pMasteringDisplayMetadata->max_luminance.num /
                     (float)pMasteringDisplayMetadata->max_luminance.den;
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
struct SwsContextContainer {
  struct SwsContext *context;
};

static void SDLCALL FreeSwsContextContainer(void *userdata, void *value) {
  struct SwsContextContainer *sws_container =
      (struct SwsContextContainer *)value;
  if (sws_container->context) {
    sws_freeContext(sws_container->context);
  }
  SDL_free(sws_container);
  (void)userdata;
}

static bool create_or_reuse_cached_texture(SdlffContext *context, AVFrame *frame,
                                            SDL_Texture **texture) {
  int texture_width = 0, texture_height = 0;
  SDL_PixelFormat texture_format = SDL_PIXELFORMAT_UNKNOWN;

  if (*texture) {
    SDL_PropertiesID props = SDL_GetTextureProperties(*texture);
    texture_format = (SDL_PixelFormat)(uintptr_t)SDL_GetNumberProperty(
        props, SDL_PROP_TEXTURE_FORMAT_NUMBER, SDL_PIXELFORMAT_UNKNOWN);
    texture_width =
        (int)SDL_GetNumberProperty(props, SDL_PROP_TEXTURE_WIDTH_NUMBER, 0);
    texture_height =
        (int)SDL_GetNumberProperty(props, SDL_PROP_TEXTURE_HEIGHT_NUMBER, 0);
  }
  if (!*texture || texture_width != frame->width ||
      texture_height != frame->height ||
      texture_format != SDL_PIXELFORMAT_ARGB8888) {
    if (*texture) {
      SDL_DestroyTexture(*texture);
    }

    SDL_PropertiesID props = create_video_texture_properties(
        frame, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING);
    *texture = SDL_CreateTextureWithProperties(context->renderer, props);
    SDL_DestroyProperties(props);
    if (!*texture) {
      return false;
    }

    SDL_SetTextureBlendMode(*texture, SDL_BLENDMODE_NONE);
    SDL_SetTextureScaleMode(*texture, SDL_SCALEMODE_LINEAR);
  }
  return true;
}

// Called on MAIN thread: converts a decoded AVFrame into the CPU-side buffer
// obtained from SDL_LockTexture (pixels/pitch). The SwsContext is cached in
// texture properties so it is reused across frames of the same format.
static bool fill_texture_with_frame_data(SDL_Texture *texture, AVFrame *frame,
                                         void *pixels, int pitch) {
  if (!texture || !frame || !pixels) {
    return false;
  }

  SDL_PropertiesID props = SDL_GetTextureProperties(texture);
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
      sws_container->context, frame->width, frame->height,
      (enum AVPixelFormat)frame->format, frame->width, frame->height,
      AV_PIX_FMT_BGRA, SWS_POINT, NULL, NULL, NULL);
  if (!sws_container->context) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                 "Can't initialize the conversion context");
    return false;
  }

  uint8_t *dst_planes[4] = { (uint8_t *)pixels, NULL, NULL, NULL };
  int dst_pitch[4] = { pitch, 0, 0, 0 };
  sws_scale(sws_container->context, (const uint8_t *const *)frame->data,
            frame->linesize, 0, frame->height, dst_planes, dst_pitch);

  // Force alpha to fully opaque; sws_scale sets A=0 for non-alpha sources.
  uint8_t *p = (uint8_t *)pixels;
  int total_bytes = pitch * frame->height;
  for (int i = 3; i < total_bytes; i += 4) {
    p[i] = 255;
  }

  return true;
}

// Called on MAIN thread: create/reuse texture, convert frame via sws_scale
// into the locked CPU buffer, upload to GPU, and render.
static void render_frame_main_thread(SdlffContext *context, AVFrame *frame) {
  if (!create_or_reuse_cached_texture(context, frame, &context->video_texture)) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                 "Couldn't get texture for frame: %s", SDL_GetError());
    return;
  }

  void *pixels = NULL;
  int pitch = 0;
  if (!SDL_LockTexture(context->video_texture, NULL, &pixels, &pitch)) {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                 "SDL_LockTexture failed: %s", SDL_GetError());
    return;
  }

  fill_texture_with_frame_data(context->video_texture, frame, pixels, pitch);
  // SDL_UnlockTexture uploads the CPU buffer to the GPU.
  SDL_UnlockTexture(context->video_texture);

  SDL_SetRenderDrawColor(context->renderer, 0, 0, 0, 255);
  SDL_RenderClear(context->renderer);

  if (context->video_texture) {
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

  SDL_RenderPresent(context->renderer);
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

void sdlffclib_main_loop(SdlffContext *context) {
  SDL_Event event;
  bool should_break = false;

  /* Record the wall-clock start time and kick the video thread */
  context->play_start_time = SDL_GetTicksNS();
  VideoThreadCommand command = VTC_PLAY;
  mailbox_send(&context->video_thread_mailbox, &command, sizeof(command));

  while (!should_break) {
    /* 1 ms timeout so frame-timing checks run every tick even without events */
    if (SDL_WaitEventTimeout(&event, 1)) {
      switch (event.type) {
      case SDL_EVENT_QUIT:
        should_break = true;
        break;
      case SDL_EVENT_KEY_DOWN:
        should_break = handle_key_should_quit(&event.key);
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
              should_break = true;
            }
          } else {
            mailbox_unlock(&context->main_thread_mailbox);
          }
        }
        break;
      }
    }

    /* Pop and render any frame whose PTS has been reached */
    if (!should_break) {
      double elapsed =
          (double)(SDL_GetTicksNS() - context->play_start_time) / 1.0e9;
      AVFrame *frame = frame_queue_try_pop(&context->frame_queue, elapsed);
      if (frame) {
        render_frame_main_thread(context, frame);
        av_frame_free(&frame);
      }
    }
  }
  SDL_Log("Quit.");
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
