/// private api
#pragma once
#include "sdlffcd_clib.h"
#include <SDL3/SDL.h>
#include <stdbool.h>
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>
#include <libswscale/swscale.h>

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

    /* Reused hardware rendering resources (lifetime managed by vctx until sdlffcd_video_close) */
    SDL_Texture* texture;        /* Owned by vctx; created on demand and destroyed in sdlffcd_video_close */
    int texture_width;           /* Width of current vctx->texture in pixels */
    int texture_height;          /* Height of current vctx->texture in pixels */

    /* Software format conversion context (lifetime managed by vctx until sdlffcd_video_close) */
    struct SwsContext* sws_ctx;  /* Owned by vctx; allocated when pixel format conversion is required */
    uint8_t* sws_data[4];        /* Pointers to sws conversion output plane buffers owned by vctx */
    int sws_linesize[4];         /* Pitches/strides for sws conversion plane buffers */
};
