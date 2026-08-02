#include "video_render.h"

// sdl
#include <SDL3/SDL_pixels.h>
#include <SDL3/SDL_render.h>

// ffmpeg
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>
#include <libavutil/mastering_display_metadata.h>
#include <libavutil/pixdesc.h>
#include <libswscale/swscale.h>

// std
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>

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
  for (int y = 0; y < frame->height; ++y) {
    uint8_t *row = (uint8_t *)pixels + y * pitch;
    for (int x = 0; x < frame->width; ++x) {
      row[x * 4 + 3] = 255;
    }
  }

  return true;
}

void render_frame_main_thread(SdlffContext *context, AVFrame *frame) {
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

    int win_w = 0, win_h = 0;
    SDL_GetRenderOutputSize(context->renderer, &win_w, &win_h);

    SDL_FRect dst;
    if (win_w > 0 && win_h > 0 && frame->width > 0 && frame->height > 0) {
      float aspect = (float)frame->width / (float)frame->height;
      if ((float)win_w / (float)win_h > aspect) {
        dst.h = (float)win_h;
        dst.w = dst.h * aspect;
        dst.x = ((float)win_w - dst.w) * 0.5f;
        dst.y = 0.0f;
      } else {
        dst.w = (float)win_w;
        dst.h = dst.w / aspect;
        dst.x = 0.0f;
        dst.y = ((float)win_h - dst.h) * 0.5f;
      }
    } else {
      dst.x = 0.0f;
      dst.y = 0.0f;
      dst.w = (float)frame->width;
      dst.h = (float)frame->height;
    }

    if (frame->linesize[0] < 0) {
      SDL_RenderTextureRotated(context->renderer, context->video_texture, &src,
                               &dst, 0.0, NULL, SDL_FLIP_VERTICAL);
    } else {
      SDL_RenderTexture(context->renderer, context->video_texture, &src, &dst);
    }
  }

  SDL_RenderPresent(context->renderer);
}
