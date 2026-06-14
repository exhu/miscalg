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

/// commands that main thread expects:
typedef enum {
  /// create texture from the active frame data, and lock pixel pointer
  MTC_CREATE_TEXTURE_FOR_FRAME,
  /// unlock texture pointer and render it
  MTC_RENDER_FRAME,
  /// end of stream reached
  MTC_VIDEO_END,
} MainThreadCommand;

/// commands that video thread expects:
typedef enum {
  /// exit from stream function
  VTC_QUIT,
  /// start playing the stream
  VTC_PLAY,
  /// write to the locked texture buffer
  VTC_FILL_TEXTURE,
} VideoThreadCommand;


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
  MainThreadCommand main_thread_mailbox_data;
  VideoThreadCommand video_thread_mailbox_data;
};
