#pragma once
#include "sdlffclib.h"
#include <SDL3/SDL.h>
#include <SDL3/SDL_atomic.h>
#include <SDL3/SDL_render.h>
#include <SDL3/SDL_timer.h>
#include <SDL3/SDL_thread.h>
#include <SDL3/SDL_mutex.h>
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswresample/swresample.h>

#include "mailbox.h"
#include "frame_queue.h"

typedef struct {
  /// input context
  AVFormatContext *ic;
  const AVCodec *audio_codec;
  const AVCodec *video_codec;
  AVCodecContext *audio_context;
  AVCodecContext *video_context;
  SwrContext *swr_ctx;
  AVPacket *pkt;
  AVFrame *frame;
  AVFrame *audio_frame;
  double first_pts;
  double seek_target_pts;
  int audio_stream;
  int video_stream;
  bool flushing;
  bool has_pending_pkt;
} SdlffVideoFileContext;

/// commands that main thread expects (sent by video thread):
typedef enum {
  /// end of stream reached
  MTC_VIDEO_END,
} MainThreadCommand;

/// commands that video thread expects (sent by main thread):
typedef enum {
  /// signal video thread to exit
  VTC_QUIT,
  /// start playing the stream
  VTC_PLAY,
  /// seek to position
  VTC_SEEK,
} VideoThreadCommand;

typedef struct {
  double seek_target_sec;              ///< target playback position in seconds (used with VTC_SEEK)
  VideoThreadCommand command;
} VideoThreadMsg;


struct _SdlffContext {
  SDL_Window *window;
  SDL_Renderer *renderer;
  SDL_Texture *video_texture;
  SDL_Thread *video_thread;
  SDL_AudioStream *audio_stream;
  Uint64 play_start_time;              ///< SDL_GetTicksNS() captured when playback begins
  Uint64 pause_start_ticks;            ///< SDL_GetTicksNS() captured when paused
  SdlffVideoFileContext video_file_ctx;
  FrameQueue frame_queue;              ///< decoded frames produced by video thread
  MailBox video_thread_mailbox;
  MailBox main_thread_mailbox;
  VideoThreadMsg video_thread_mailbox_data;
  Uint32 main_thread_event;
  MainThreadCommand main_thread_mailbox_data;
  SDL_AtomicInt quit_requested;       ///< set to 1 to signal video thread to exit
  bool paused;                         ///< true if playback is paused
  bool show_overlay;                   ///< true if timestamp overlay is visible (toggled via 'O' key)
  bool exit_at_end;
  bool stream_ended;                   ///< true if stream reached EOF
  double min_seek_increment;           ///< cached minimal seek increment in seconds (frame duration)
  double in_point; ///< first frame of the cut
  double out_point; ///< last frame (inclusive) of the cut
};
