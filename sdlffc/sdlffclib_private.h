#pragma once
#include <SDL3/SDL.h>
#include <SDL3/SDL_render.h>
#include <SDL3/SDL_timer.h>
#include <SDL3/SDL_thread.h>
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>

#include "mailbox.h"

typedef struct {
  /// input context
  AVFormatContext *ic;
  const AVCodec *audio_codec;
  const AVCodec *video_codec;
  AVCodecContext *audio_context;
  AVCodecContext *video_context;
  AVPacket *pkt;
  AVFrame *frame;
  int audio_stream;
  int video_stream;
  bool flushing;
  double first_pts;
} SdlffVideoFileContext;

struct _SdlffContext {
  SDL_Window *window;
  SDL_Renderer *renderer;
  SDL_Texture *video_texture;
  SdlffVideoFileContext video_file_ctx;
  SDL_TimerID timer_id;
  Uint32 main_thread_event;
  SDL_Thread *video_thread;
  MailBox video_thread_mailbox;
  MailBox main_thread_mailbox;
};
