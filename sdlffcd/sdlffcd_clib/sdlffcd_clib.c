#include "sdlffcd_clib.h"
#include "sdlffcd_clib_private.h"

#include <stdio.h>
#include <stdlib.h>

sdlffcd_AppContext* sdlffcd_app_init(const char* title, int width, int height) {
    if (!SDL_Init(SDL_INIT_VIDEO)) {
        fprintf(stderr, "Failed to initialize SDL: %s\n", SDL_GetError());
        return NULL;
    }

    sdlffcd_AppContext* app = (sdlffcd_AppContext*)calloc(1, sizeof(sdlffcd_AppContext));
    if (!app) {
        SDL_Quit();
        return NULL;
    }

    app->window = SDL_CreateWindow(title, width, height, SDL_WINDOW_RESIZABLE);
    if (!app->window) {
        fprintf(stderr, "Failed to create SDL window: %s\n", SDL_GetError());
        free(app);
        SDL_Quit();
        return NULL;
    }

    app->renderer = SDL_CreateRenderer(app->window, NULL);
    if (!app->renderer) {
        fprintf(stderr, "Failed to create SDL renderer: %s\n", SDL_GetError());
        SDL_DestroyWindow(app->window);
        free(app);
        SDL_Quit();
        return NULL;
    }

    app->running = true;
    return app;
}

bool sdlffcd_app_is_running(const sdlffcd_AppContext* app) {
    return app && app->running;
}

void sdlffcd_app_wait_events(sdlffcd_AppContext* app) {
    if (!app) return;
    SDL_Event event;
    if (SDL_WaitEvent(&event)) {
        do {
            if (event.type == SDL_EVENT_QUIT) {
                app->running = false;
            } else if (event.type == SDL_EVENT_KEY_DOWN) {
                if (event.key.key == SDLK_ESCAPE || event.key.key == SDLK_Q) {
                    app->running = false;
                }
            }
        } while (SDL_PollEvent(&event));
    }
}

void sdlffcd_app_render(sdlffcd_AppContext* app) {
    if (!app || !app->renderer) return;
    SDL_SetRenderDrawColor(app->renderer, 30, 32, 40, 255);
    SDL_RenderClear(app->renderer);
    SDL_RenderPresent(app->renderer);
}

void sdlffcd_app_shutdown(sdlffcd_AppContext* app) {
    if (!app) return;
    if (app->renderer) SDL_DestroyRenderer(app->renderer);
    if (app->window) SDL_DestroyWindow(app->window);
    SDL_Quit();
    free(app);
}

/* --- Video API Implementation --- */

sdlffcd_VideoContext* sdlffcd_video_open(const char* filename) {
    if (!filename) return NULL;

    sdlffcd_VideoContext* vctx = (sdlffcd_VideoContext*)calloc(1, sizeof(sdlffcd_VideoContext));
    if (!vctx) return NULL;

    vctx->video_stream_idx = -1;
    vctx->audio_stream_idx = -1;

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
        snprintf(vctx->info.audio_codec_name, sizeof(vctx->info.audio_codec_name), "%s", audio_codec->name ? audio_codec->name : "unknown");
    } else {
        snprintf(vctx->info.audio_codec_name, sizeof(vctx->info.audio_codec_name), "none");
    }

    vctx->frame = av_frame_alloc();
    vctx->pkt = av_packet_alloc();
    if (!vctx->frame || !vctx->pkt) {
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

sdlffcd_DecodeStatus sdlffcd_video_decode_frame(sdlffcd_VideoContext* vctx, sdlffcd_VideoFrame* out_frame) {
    if (!vctx || !out_frame || !vctx->video_codec_ctx || vctx->video_stream_idx < 0) {
        return SDLFFCD_DECODE_ERROR;
    }

    while (1) {
        int ret = avcodec_receive_frame(vctx->video_codec_ctx, vctx->frame);
        if (ret == 0) {
            for (int i = 0; i < 8; i++) {
                out_frame->data[i] = vctx->frame->data[i];
                out_frame->linesize[i] = vctx->frame->linesize[i];
            }
            out_frame->width = vctx->frame->width;
            out_frame->height = vctx->frame->height;
            out_frame->pixel_format = vctx->frame->format;

            AVStream* vst = vctx->fmt_ctx->streams[vctx->video_stream_idx];
            if (vctx->frame->pts != AV_NOPTS_VALUE) {
                out_frame->pts = (double)vctx->frame->pts * av_q2d(vst->time_base);
            } else {
                out_frame->pts = 0.0;
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
            } else {
                av_packet_unref(vctx->pkt);
            }
        }
    }
}

void sdlffcd_video_close(sdlffcd_VideoContext* vctx) {
    if (!vctx) return;
    if (vctx->frame) av_frame_free(&vctx->frame);
    if (vctx->pkt) av_packet_free(&vctx->pkt);
    if (vctx->video_codec_ctx) avcodec_free_context(&vctx->video_codec_ctx);
    if (vctx->audio_codec_ctx) avcodec_free_context(&vctx->audio_codec_ctx);
    if (vctx->fmt_ctx) avformat_close_input(&vctx->fmt_ctx);
    free(vctx);
}
