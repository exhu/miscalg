#include "sdlffcd_ffmpeg.h"
#include "sdlffcd_ffmpeg_private.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

sdlffcd_VideoContext* sdlffcd_video_open(const char* filename) {
    if (!filename) return NULL;

    sdlffcd_VideoContext* vctx = (sdlffcd_VideoContext*)calloc(1, sizeof(sdlffcd_VideoContext));
    if (!vctx) return NULL;

    vctx->video_stream_idx = -1;
    vctx->audio_stream_idx = -1;
    vctx->seek_min_audio_pts = -1.0;

    if (avformat_open_input(&vctx->fmt_ctx, filename, NULL, NULL) < 0) {
        free(vctx);
        return NULL;
    }

    if (avformat_find_stream_info(vctx->fmt_ctx, NULL) < 0) {
        avformat_close_input(&vctx->fmt_ctx);
        free(vctx);
        return NULL;
    }

    if (vctx->fmt_ctx->iformat && vctx->fmt_ctx->iformat->name) {
        snprintf(vctx->info.format_name, sizeof(vctx->info.format_name), "%s", vctx->fmt_ctx->iformat->name);
    } else {
        snprintf(vctx->info.format_name, sizeof(vctx->info.format_name), "unknown");
    }

    vctx->info.num_streams = (int)vctx->fmt_ctx->nb_streams;

    if (vctx->fmt_ctx->duration != AV_NOPTS_VALUE) {
        vctx->info.duration_seconds = (double)vctx->fmt_ctx->duration / (double)AV_TIME_BASE;
    } else {
        vctx->info.duration_seconds = 0.0;
    }

    const AVCodec* video_codec = NULL;
    vctx->video_stream_idx = av_find_best_stream(vctx->fmt_ctx, AVMEDIA_TYPE_VIDEO, -1, -1, &video_codec, 0);
    vctx->info.video_stream_index = (vctx->video_stream_idx >= 0) ? vctx->video_stream_idx : -1;

    if (vctx->video_stream_idx >= 0 && video_codec) {
        AVStream* vst = vctx->fmt_ctx->streams[vctx->video_stream_idx];
        vctx->video_codec_ctx = avcodec_alloc_context3(video_codec);
        if (vctx->video_codec_ctx) {
            avcodec_parameters_to_context(vctx->video_codec_ctx, vst->codecpar);
            vctx->video_codec_ctx->pkt_timebase = vst->time_base;
            if (avcodec_open2(vctx->video_codec_ctx, video_codec, NULL) < 0) {
                avcodec_free_context(&vctx->video_codec_ctx);
            }
        }

        snprintf(vctx->info.video_codec_name, sizeof(vctx->info.video_codec_name), "%s", video_codec->name ? video_codec->name : "unknown");
        vctx->info.width = vst->codecpar->width;
        vctx->info.height = vst->codecpar->height;
        vctx->info.pixel_format = vst->codecpar->format;
        vctx->info.num_frames = vst->nb_frames;

        if (vst->r_frame_rate.den != 0) {
            vctx->info.fps = av_q2d(vst->r_frame_rate);
        } else if (vst->avg_frame_rate.den != 0) {
            vctx->info.fps = av_q2d(vst->avg_frame_rate);
        } else {
            vctx->info.fps = 0.0;
        }
    } else {
        snprintf(vctx->info.video_codec_name, sizeof(vctx->info.video_codec_name), "none");
    }

    const AVCodec* audio_codec = NULL;
    vctx->audio_stream_idx = av_find_best_stream(vctx->fmt_ctx, AVMEDIA_TYPE_AUDIO, -1, -1, &audio_codec, 0);
    vctx->info.audio_stream_index = (vctx->audio_stream_idx >= 0) ? vctx->audio_stream_idx : -1;

    if (vctx->audio_stream_idx >= 0 && audio_codec) {
        AVStream* ast = vctx->fmt_ctx->streams[vctx->audio_stream_idx];
        vctx->audio_codec_ctx = avcodec_alloc_context3(audio_codec);
        if (vctx->audio_codec_ctx) {
            avcodec_parameters_to_context(vctx->audio_codec_ctx, ast->codecpar);
            vctx->audio_codec_ctx->pkt_timebase = ast->time_base;
            if (avcodec_open2(vctx->audio_codec_ctx, audio_codec, NULL) < 0) {
                avcodec_free_context(&vctx->audio_codec_ctx);
            }
        }

        snprintf(vctx->info.audio_codec_name, sizeof(vctx->info.audio_codec_name), "%s", audio_codec->name ? audio_codec->name : "unknown");

        if (vctx->audio_codec_ctx) {
            vctx->audio_target_channels = 2;
            vctx->audio_target_sample_rate = (vctx->audio_codec_ctx->sample_rate > 0) ? vctx->audio_codec_ctx->sample_rate : 44100;
            vctx->info.audio_sample_rate = vctx->audio_target_sample_rate;
            vctx->info.audio_channels = vctx->audio_target_channels;

            AVChannelLayout out_ch_layout = AV_CHANNEL_LAYOUT_STEREO;
            AVChannelLayout in_ch_layout;
            if (vctx->audio_codec_ctx->ch_layout.nb_channels > 0) {
                av_channel_layout_copy(&in_ch_layout, &vctx->audio_codec_ctx->ch_layout);
            } else {
                av_channel_layout_default(&in_ch_layout, 2);
            }

            int swr_res = swr_alloc_set_opts2(
                &vctx->swr_ctx,
                &out_ch_layout,
                AV_SAMPLE_FMT_S16,
                vctx->audio_target_sample_rate,
                &in_ch_layout,
                vctx->audio_codec_ctx->sample_fmt,
                vctx->audio_codec_ctx->sample_rate,
                0, NULL
            );
            av_channel_layout_uninit(&in_ch_layout);

            if (swr_res >= 0 && vctx->swr_ctx) {
                if (swr_init(vctx->swr_ctx) < 0) {
                    swr_free(&vctx->swr_ctx);
                    vctx->swr_ctx = NULL;
                }
            }
        }
    } else {
        snprintf(vctx->info.audio_codec_name, sizeof(vctx->info.audio_codec_name), "none");
        vctx->info.audio_sample_rate = 0;
        vctx->info.audio_channels = 0;
    }

    vctx->frame = av_frame_alloc();
    vctx->audio_frame = av_frame_alloc();
    vctx->pkt = av_packet_alloc();
    if (!vctx->frame || !vctx->audio_frame || !vctx->pkt) {
        sdlffcd_video_close(vctx);
        return NULL;
    }

    return vctx;
}

bool sdlffcd_video_get_media_info(const sdlffcd_VideoContext* vctx, sdlffcd_MediaInfo* out_info) {
    if (!vctx || !out_info) return false;
    *out_info = vctx->info;
    return true;
}

void sdlffcd_video_set_audio_callback(sdlffcd_VideoContext* vctx, sdlffcd_AudioDataCallback cb, void* userdata) {
    if (!vctx) return;
    vctx->audio_callback = cb;
    vctx->audio_callback_userdata = userdata;
}

static void process_audio_packet(sdlffcd_VideoContext* vctx, AVPacket* pkt) {
    if (!vctx || !vctx->audio_codec_ctx || !vctx->swr_ctx || !vctx->audio_frame) return;

    int ret = avcodec_send_packet(vctx->audio_codec_ctx, pkt);
    if (ret < 0) return;

    while (avcodec_receive_frame(vctx->audio_codec_ctx, vctx->audio_frame) == 0) {
        if (vctx->seek_min_audio_pts >= 0.0 && vctx->audio_stream_idx >= 0) {
            AVStream* ast = vctx->fmt_ctx->streams[vctx->audio_stream_idx];
            double frame_pts = 0.0;
            if (vctx->audio_frame->pts != AV_NOPTS_VALUE) {
                frame_pts = (double)vctx->audio_frame->pts * av_q2d(ast->time_base);
            }
            if (frame_pts < vctx->seek_min_audio_pts) {
                continue;
            }
        }

        int out_samples = (int)av_rescale_rnd(
            swr_get_delay(vctx->swr_ctx, vctx->audio_codec_ctx->sample_rate) + vctx->audio_frame->nb_samples,
            vctx->audio_target_sample_rate,
            vctx->audio_codec_ctx->sample_rate,
            AV_ROUND_UP
        );

        int bytes_needed = out_samples * vctx->audio_target_channels * (int)sizeof(int16_t);
        if (vctx->audio_resample_buf_size < bytes_needed) {
            uint8_t* new_buf = (uint8_t*)realloc(vctx->audio_resample_buf, (size_t)bytes_needed + 1024);
            if (!new_buf) continue;
            vctx->audio_resample_buf = new_buf;
            vctx->audio_resample_buf_size = bytes_needed + 1024;
        }

        uint8_t* out_ptr = vctx->audio_resample_buf;
        const uint8_t** in_ptr = (const uint8_t**)(void*)vctx->audio_frame->data;
        int converted_samples = swr_convert(
            vctx->swr_ctx,
            &out_ptr,
            out_samples,
            in_ptr,
            vctx->audio_frame->nb_samples
        );

        if (converted_samples > 0 && vctx->audio_callback) {
            int converted_bytes = converted_samples * vctx->audio_target_channels * (int)sizeof(int16_t);
            vctx->audio_callback(vctx->audio_callback_userdata, vctx->audio_resample_buf, converted_bytes);
        }
    }
}

sdlffcd_DecodeStatus sdlffcd_video_decode_frame(sdlffcd_VideoContext* vctx, sdlffcd_VideoFrame* out_frame) {
    if (!vctx || !out_frame || !vctx->video_codec_ctx || vctx->video_stream_idx < 0) {
        return SDLFFCD_DECODE_ERROR;
    }

    if (vctx->has_cached_frame) {
        *out_frame = vctx->cached_frame;
        vctx->has_cached_frame = false;
        return SDLFFCD_DECODE_OK;
    }

    while (1) {
        int ret = avcodec_receive_frame(vctx->video_codec_ctx, vctx->frame);
        if (ret == 0) {
            if (vctx->frame->format == AV_PIX_FMT_YUV420P || vctx->frame->format == AV_PIX_FMT_YUVJ420P) {
                for (int i = 0; i < 8; i++) {
                    out_frame->data[i] = vctx->frame->data[i];
                    out_frame->linesize[i] = vctx->frame->linesize[i];
                }
                out_frame->width = vctx->frame->width;
                out_frame->height = vctx->frame->height;
                out_frame->pixel_format = vctx->frame->format;
            } else {
                if (!vctx->sws_ctx) {
                    vctx->sws_ctx = sws_getContext(
                        vctx->frame->width, vctx->frame->height, (enum AVPixelFormat)vctx->frame->format,
                        vctx->frame->width, vctx->frame->height, AV_PIX_FMT_YUV420P,
                        SWS_BILINEAR, NULL, NULL, NULL);
                    if (!vctx->sws_ctx) return SDLFFCD_DECODE_ERROR;

                    if (av_image_alloc(vctx->sws_data, vctx->sws_linesize, vctx->frame->width, vctx->frame->height, AV_PIX_FMT_YUV420P, 1) < 0) {
                        sws_freeContext(vctx->sws_ctx);
                        vctx->sws_ctx = NULL;
                        return SDLFFCD_DECODE_ERROR;
                    }
                }

                sws_scale(vctx->sws_ctx, (const uint8_t* const*)vctx->frame->data, vctx->frame->linesize,
                          0, vctx->frame->height, vctx->sws_data, vctx->sws_linesize);

                for (int i = 0; i < 4; i++) {
                    out_frame->data[i] = vctx->sws_data[i];
                    out_frame->linesize[i] = vctx->sws_linesize[i];
                }
                for (int i = 4; i < 8; i++) {
                    out_frame->data[i] = NULL;
                    out_frame->linesize[i] = 0;
                }
                out_frame->width = vctx->frame->width;
                out_frame->height = vctx->frame->height;
                out_frame->pixel_format = AV_PIX_FMT_YUV420P;
            }

            AVStream* vst = vctx->fmt_ctx->streams[vctx->video_stream_idx];
            int64_t pts = vctx->frame->pts;
            if (pts == AV_NOPTS_VALUE) {
                pts = vctx->frame->best_effort_timestamp;
            }
            if (pts != AV_NOPTS_VALUE) {
                out_frame->pts = (double)pts * av_q2d(vst->time_base);
            } else {
                out_frame->pts = -1.0;
            }

            return SDLFFCD_DECODE_OK;
        }

        if (ret != AVERROR(EAGAIN)) {
            if (ret == AVERROR_EOF) {
                return SDLFFCD_DECODE_EOF;
            }
            return SDLFFCD_DECODE_ERROR;
        }

        ret = av_read_frame(vctx->fmt_ctx, vctx->pkt);
        if (ret < 0) {
            if (ret == AVERROR_EOF) {
                avcodec_send_packet(vctx->video_codec_ctx, NULL);
                if (vctx->audio_codec_ctx) {
                    process_audio_packet(vctx, NULL);
                }
            } else {
                return SDLFFCD_DECODE_ERROR;
            }
        } else {
            if (vctx->pkt->stream_index == vctx->video_stream_idx) {
                int send_ret = avcodec_send_packet(vctx->video_codec_ctx, vctx->pkt);
                av_packet_unref(vctx->pkt);
                if (send_ret < 0 && send_ret != AVERROR(EAGAIN) && send_ret != AVERROR_EOF) {
                    return SDLFFCD_DECODE_ERROR;
                }
            } else if (vctx->audio_stream_idx >= 0 && vctx->pkt->stream_index == vctx->audio_stream_idx) {
                process_audio_packet(vctx, vctx->pkt);
                av_packet_unref(vctx->pkt);
            } else {
                av_packet_unref(vctx->pkt);
            }
        }
    }
}

bool sdlffcd_video_seek(sdlffcd_VideoContext* vctx, double target_pts_seconds) {
    if (!vctx || !vctx->fmt_ctx || vctx->video_stream_idx < 0) return false;

    AVStream* vst = vctx->fmt_ctx->streams[vctx->video_stream_idx];
    int64_t target_ts = av_rescale_q((int64_t)(target_pts_seconds * AV_TIME_BASE), AV_TIME_BASE_Q, vst->time_base);

    if (av_seek_frame(vctx->fmt_ctx, vctx->video_stream_idx, target_ts, AVSEEK_FLAG_BACKWARD) < 0) {
        return false;
    }

    if (vctx->video_codec_ctx) {
        avcodec_flush_buffers(vctx->video_codec_ctx);
    }
    if (vctx->audio_codec_ctx) {
        avcodec_flush_buffers(vctx->audio_codec_ctx);
    }
    if (vctx->swr_ctx) {
        swr_init(vctx->swr_ctx);
    }
    vctx->has_cached_frame = false;

    if (target_pts_seconds > 0.0) {
        vctx->seek_min_audio_pts = target_pts_seconds;
        double frame_dur = (vctx->info.fps > 0.0) ? (1.0 / vctx->info.fps) : 0.033;
        double threshold = target_pts_seconds - (frame_dur * 0.5);
        while (1) {
            sdlffcd_DecodeStatus st = sdlffcd_video_decode_frame(vctx, &vctx->cached_frame);
            if (st != SDLFFCD_DECODE_OK) {
                break;
            }
            if (vctx->cached_frame.pts >= threshold) {
                vctx->has_cached_frame = true;
                break;
            }
        }
        vctx->seek_min_audio_pts = -1.0;
    }

    return true;
}

bool sdlffcd_video_has_audio(const sdlffcd_VideoContext* vctx) {
    return vctx && vctx->audio_codec_ctx && vctx->swr_ctx;
}

void sdlffcd_video_close(sdlffcd_VideoContext* vctx) {
    if (!vctx) return;
    if (vctx->swr_ctx) {
        swr_free(&vctx->swr_ctx);
        vctx->swr_ctx = NULL;
    }
    if (vctx->audio_resample_buf) {
        free(vctx->audio_resample_buf);
        vctx->audio_resample_buf = NULL;
        vctx->audio_resample_buf_size = 0;
    }
    if (vctx->sws_ctx) {
        sws_freeContext(vctx->sws_ctx);
        vctx->sws_ctx = NULL;
    }
    if (vctx->sws_data[0]) {
        av_freep(&vctx->sws_data[0]);
    }
    if (vctx->frame) av_frame_free(&vctx->frame);
    if (vctx->audio_frame) av_frame_free(&vctx->audio_frame);
    if (vctx->pkt) av_packet_free(&vctx->pkt);
    if (vctx->video_codec_ctx) avcodec_free_context(&vctx->video_codec_ctx);
    if (vctx->audio_codec_ctx) avcodec_free_context(&vctx->audio_codec_ctx);
    if (vctx->fmt_ctx) avformat_close_input(&vctx->fmt_ctx);
    free(vctx);
}
