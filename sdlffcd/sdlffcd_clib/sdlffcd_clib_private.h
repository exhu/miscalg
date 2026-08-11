/// private api
#pragma once
#include "sdlffcd_clib.h"
#include <SDL3/SDL.h>
#include <stdbool.h>
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>

struct sdlffcd_AppContext {
    SDL_Window* window;
    SDL_Renderer* renderer;
    bool running;
};

struct sdlffcd_VideoContext {
    AVFormatContext* fmt_ctx;
    AVCodecContext* video_codec_ctx;
    AVCodecContext* audio_codec_ctx;
    int video_stream_idx;
    int audio_stream_idx;
    AVFrame* frame;
    AVPacket* pkt;
    sdlffcd_MediaInfo info;
};
