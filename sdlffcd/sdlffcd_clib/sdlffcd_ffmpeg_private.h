/// private api for sdlffcd_ffmpeg
#pragma once
#include "sdlffcd_ffmpeg.h"

#include <stdbool.h>
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>
#include <libavutil/channel_layout.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>

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

    /* Software format conversion context (converts non-YUV420P to standard YUV420P) */
    struct SwsContext* sws_ctx;
    uint8_t* sws_data[4];
    int sws_linesize[4];

    /* Audio resampling resources (resamples audio to standard 16-bit stereo PCM) */
    struct SwrContext* swr_ctx;
    uint8_t* audio_resample_buf;
    int audio_resample_buf_size;
    int audio_target_sample_rate;
    int audio_target_channels;
    uint8_t _pad_audio[4];
    double seek_min_audio_pts;

    /* Audio packet callback */
    sdlffcd_AudioDataCallback audio_callback;
    void* audio_callback_userdata;

    /* Frame-accurate seek cache */
    bool has_cached_frame;
    uint8_t _pad_seek[7];
    sdlffcd_VideoFrame cached_frame;
};
