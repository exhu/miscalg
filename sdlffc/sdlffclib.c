#include "sdlffclib.h"
#include "sdlffclib_private.h"
#include <SDL3/SDL_events.h>
#include <SDL3/SDL_hints.h>
#include <SDL3/SDL_init.h>
#include <SDL3/SDL_pixels.h>
#include <SDL3/SDL_render.h>
#include <SDL3/SDL_video.h>
#include <SDL3/SDL_dialog.h>

#include <libavformat/avformat.h>
#include <libavutil/avutil.h>

#include <libavutil/rational.h>
#include <memory.h>
#include <stdbool.h>

bool sdlffclib_init(SdlffContext **out_context) {
  static SdlffContext global_context = {
      .window = NULL,
      .renderer = NULL,
      .streaming_texture = NULL,
  };

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

void sdlffclib_done(SdlffContext **out_context) {
  SDL_DestroyTexture((*out_context)->streaming_texture);
  SDL_DestroyRenderer((*out_context)->renderer);
  SDL_DestroyWindow((*out_context)->window);
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

static void dialog_cb(void *userdata, const char * const *filelist, int filter) {
  if (filelist != NULL) {
    SDL_Log("Selected '%s'", filelist[0]);
  } else {
    SDL_Log("Nothing selected.");
  }
}

void sdlffclib_main_loop(SdlffContext *context) {
  //SDL_ShowOpenFileDialog(dialog_cb, NULL, context->window, NULL, 0, NULL, false);
  SDL_Event event;
  while (SDL_WaitEvent(&event)) {
    if (event.type == SDL_EVENT_QUIT)
      break;
    if (event.type == SDL_EVENT_WINDOW_EXPOSED)
      sdlffclib_render(context);
  }
  SDL_Log("Quit.");
}

bool sdlffclib_fileinfo(const char *file_path) {
    AVFormatContext *ic = NULL;
    int result = avformat_open_input(&ic, file_path, NULL, NULL);
    if (result < 0) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Couldn't open %s: %d", file_path, result);
	return false;
    }
    result = avformat_find_stream_info(ic, NULL);
    if (result < 0) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Couldn't read stream info %s: %d", file_path, result);
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
      double duration = (double)(stream->duration * stream->time_base.num) / stream->time_base.den;
      SDL_Log("Duration on time base: %f", duration);
      SDL_Log("Frame rate: %d/%d", stream->r_frame_rate.num, stream->r_frame_rate.den);
      const enum AVMediaType media_type = stream->codecpar->codec_type;
      SDL_Log("Codec type: %d, %s", media_type, media_type == AVMEDIA_TYPE_AUDIO ? "audio" : media_type == AVMEDIA_TYPE_VIDEO ? "video" : "other" );
    }

    avformat_close_input(&ic);

    return true;
}
