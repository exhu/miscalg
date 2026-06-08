#include "sdlffclib.h"
#include "SDL3/SDL_keycode.h"
#include "SDL3/SDL_scancode.h"
#include "sdlffclib_private.h"
#include <SDL3/SDL_dialog.h>
#include <SDL3/SDL_events.h>
#include <SDL3/SDL_hints.h>
#include <SDL3/SDL_init.h>
#include <SDL3/SDL_pixels.h>
#include <SDL3/SDL_render.h>
#include <SDL3/SDL_video.h>

#include <libavformat/avformat.h>
#include <libavutil/avutil.h>

#include <libavutil/rational.h>
#include <memory.h>
#include <stdbool.h>

bool sdlffclib_init(SdlffContext **out_context) {
  static SdlffContext global_context;
  memset(&global_context, 0, sizeof(SdlffContext));

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
  SDL_SetWindowMinimumSize(context->window, 320, 200);
  SDL_SetRenderVSync(context->renderer, SDL_RENDERER_VSYNC_ADAPTIVE);

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
    // TODO
    #if 0
    av_frame_free(&ctx->frame);
    av_packet_free(&ctx->pkt);
    avcodec_free_context(&ctx->audio_context);
    #endif
    avcodec_free_context(&ctx->video_context);
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

void sdlffclib_main_loop(SdlffContext *context) {
  // SDL_ShowOpenFileDialog(dialog_cb, NULL, context->window, NULL, 0, NULL,
  // false);
  SDL_Event event;
  bool should_break = false;
  while (!should_break && SDL_WaitEvent(&event)) {
    switch (event.type) {
    case SDL_EVENT_QUIT:
      should_break = true;
      break;
    case SDL_EVENT_WINDOW_EXPOSED:
      sdlffclib_render(context);
      break;
    case SDL_EVENT_KEY_DOWN:
      if (event.key.key == SDLK_Q) {
        should_break = true;
        break;
      }

    default:;
    }
  }
  SDL_Log("Quit.");
}


/// based on OpenVideoStream from testffmpeg.c
static AVCodecContext *open_video_stream(AVFormatContext *ic, int stream, const AVCodec *codec)
{
    AVStream *st = ic->streams[stream];
    AVCodecParameters *codecpar = st->codecpar;
    AVCodecContext *context;
    const AVCodecHWConfig *config;
    int i;
    int result;

    SDL_Log("Video stream: %s %dx%d", avcodec_get_name(codec->id), codecpar->width, codecpar->height);

    context = avcodec_alloc_context3(NULL);
    if (!context) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "avcodec_alloc_context3 failed");
        return NULL;
    }

    result = avcodec_parameters_to_context(context, ic->streams[stream]->codecpar);
    if (result < 0) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "avcodec_parameters_to_context failed: %s", av_err2str(result));
        avcodec_free_context(&context);
        return NULL;
    }
    context->pkt_timebase = ic->streams[stream]->time_base;

    // TODO skip hw device for now, software decoder only

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

  ctx->video_context = open_video_stream(ctx->ic, ctx->video_stream, ctx->video_codec);
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
