/// private api
#pragma once
#include "sdlffcd_clib.h"

#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wpadded"
#endif

#include <SDL3/SDL.h>
#include <SDL3_ttf/SDL_ttf.h>

#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic pop
#endif

#include <stdbool.h>
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>
#include <libavutil/channel_layout.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>

struct sdlffcd_AppContext {
    SDL_Window* window;
    SDL_Renderer* renderer;
    TTF_TextEngine* text_engine;
    uint32_t wake_event_type;
    bool running;
    bool need_redraw;
    uint8_t _pad[2];
    sdlffcd_KeyCallback key_callback;
    void* key_callback_userdata;
};

struct sdlffcd_Font {
    TTF_Font* ttf_font;
};

struct sdlffcd_Text {
    TTF_Text* ttf_text;
};

struct sdlffcd_VideoContext {
    AVFormatContext* fmt_ctx;
    AVCodecContext* video_codec_ctx;
    AVCodecContext* audio_codec_ctx;
    int video_stream_idx;
    int audio_stream_idx;
    AVFrame* frame;
    AVFrame* audio_frame;
    AVPacket* pkt;
    sdlffcd_MediaInfo info;

    /* Reused hardware rendering resources (lifetime managed by vctx until sdlffcd_video_close) */
    SDL_Texture* texture;        /* Owned by vctx; created on demand and destroyed in sdlffcd_video_close */
    int texture_width;           /* Width of current vctx->texture in pixels */
    int texture_height;          /* Height of current vctx->texture in pixels */
    int last_render_w;           /* Cached renderer output width */
    int last_render_h;           /* Cached renderer output height */
    SDL_FRect dst_rect;          /* Cached letterbox destination rectangle */

    /* Software format conversion context (lifetime managed by vctx until sdlffcd_video_close) */
    struct SwsContext* sws_ctx;  /* Owned by vctx; allocated when pixel format conversion is required */
    uint8_t* sws_data[4];        /* Pointers to sws conversion output plane buffers owned by vctx */
    int sws_linesize[4];         /* Pitches/strides for sws conversion plane buffers */

    /* Audio playback & resampling resources (lifetime managed by vctx until sdlffcd_video_close) */
    SDL_AudioStream* audio_stream; /* Owned by vctx; created when audio stream is present */
    struct SwrContext* swr_ctx;    /* Owned by vctx; resamples audio to standard stereo PCM */
    uint8_t* audio_resample_buf;   /* Buffer for resampled audio samples */
    int audio_resample_buf_size;   /* Current capacity of audio_resample_buf in bytes */
    int audio_target_sample_rate;  /* Target audio sample rate in Hz */
    int audio_target_channels;     /* Target audio channels (always 2 for stereo) */
    float audio_volume;            /* Playback volume (1.0 = 100%) */
    double seek_min_audio_pts;     /* Minimum audio PTS allowed during seek */

    /* Frame-accurate seek cache */
    bool has_cached_frame;
    uint8_t _pad_seek[7];
    sdlffcd_VideoFrame cached_frame;
};

