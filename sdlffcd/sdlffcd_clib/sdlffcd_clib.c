#include "sdlffcd_clib.h"
#include "sdlffcd_clib_private.h"

#include <stdio.h>
#include <stdlib.h>

static bool SDLCALL window_event_watch(void* userdata, SDL_Event* event) {
    sdlffcd_AppContext* app = (sdlffcd_AppContext*)userdata;
    if (!app || !event) return true;
    if (event->type == SDL_EVENT_WINDOW_RESIZED ||
        event->type == SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED ||
        event->type == SDL_EVENT_WINDOW_EXPOSED) {
        app->need_redraw = true;
    }
    return true;
}

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

    if (!TTF_Init()) {
        fprintf(stderr, "Failed to initialize SDL_ttf: %s\n", SDL_GetError());
        SDL_DestroyRenderer(app->renderer);
        SDL_DestroyWindow(app->window);
        free(app);
        SDL_Quit();
        return NULL;
    }

    app->text_engine = TTF_CreateRendererTextEngine(app->renderer);
    if (!app->text_engine) {
        fprintf(stderr, "Failed to create renderer text engine: %s\n", SDL_GetError());
        TTF_Quit();
        SDL_DestroyRenderer(app->renderer);
        SDL_DestroyWindow(app->window);
        free(app);
        SDL_Quit();
        return NULL;
    }

    app->running = true;
    app->wake_event_type = SDL_RegisterEvents(1);
    if (app->wake_event_type == (uint32_t)-1) {
        fprintf(stderr, "Failed to register custom wake event: %s\n", SDL_GetError());
    }

    SDL_AddEventWatch(window_event_watch, app);
    return app;
}

bool sdlffcd_app_is_running(const sdlffcd_AppContext* app) {
    return app && app->running;
}

void sdlffcd_app_stop(sdlffcd_AppContext* app) {
    if (app) {
        app->running = false;
    }
}

void sdlffcd_app_set_key_callback(sdlffcd_AppContext* app, sdlffcd_KeyCallback cb, void* userdata) {
    if (!app) return;
    app->key_callback = cb;
    app->key_callback_userdata = userdata;
}

static void process_single_event(sdlffcd_AppContext* app, const SDL_Event* event) {
    if (!app || !event) return;
    if (event->type == SDL_EVENT_QUIT) {
        app->running = false;
    } else if (event->type == SDL_EVENT_WINDOW_RESIZED ||
               event->type == SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED ||
               event->type == SDL_EVENT_WINDOW_EXPOSED) {
        app->need_redraw = true;
    } else if (event->type == SDL_EVENT_KEY_DOWN) {
        if (app->key_callback) {
            uint32_t key = (uint32_t)event->key.key;
            // TODO do we need this? there SDLK_A .. SDLKV_Z etc constants, so no case variation
            if (key >= 'A' && key <= 'Z') {
                key += ('a' - 'A');
            }
            app->key_callback(app->key_callback_userdata, key);
        }
    }
}

void sdlffcd_app_poll_events(sdlffcd_AppContext* app) {
    if (!app) return;
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        process_single_event(app, &event);
    }
}

void sdlffcd_app_wait_events(sdlffcd_AppContext* app, int timeout_ms) {
    if (!app) return;
    SDL_Event event;
    bool status;
    if (timeout_ms < 0) {
        status = SDL_WaitEvent(&event);
    } else if (timeout_ms == 0) {
        status = SDL_PollEvent(&event);
    } else {
        status = SDL_WaitEventTimeout(&event, timeout_ms);
    }
    if (status) {
        do {
            process_single_event(app, &event);
        } while (SDL_PollEvent(&event));
    }
}

bool sdlffcd_app_wake(sdlffcd_AppContext* app) {
    if (!app || app->wake_event_type == (uint32_t)-1) return false;
    SDL_Event event;
    SDL_zero(event);
    event.type = app->wake_event_type;
    return SDL_PushEvent(&event);
}

void sdlffcd_app_render(sdlffcd_AppContext* app) {
    if (!app || !app->renderer) return;
    SDL_SetRenderDrawColor(app->renderer, 30, 32, 40, 255);
    SDL_RenderClear(app->renderer);
    SDL_RenderPresent(app->renderer);
}

void sdlffcd_app_shutdown(sdlffcd_AppContext* app) {
    if (!app) return;
    SDL_RemoveEventWatch(window_event_watch, app);
    if (app->text_engine) {
        TTF_DestroyRendererTextEngine(app->text_engine);
        app->text_engine = NULL;
    }
    TTF_Quit();
    if (app->renderer) SDL_DestroyRenderer(app->renderer);
    if (app->window) SDL_DestroyWindow(app->window);
    SDL_Quit();
    free(app);
}

bool sdlffcd_app_need_redraw(const sdlffcd_AppContext* app) {
    return app && app->need_redraw;
}

bool sdlffcd_app_check_and_clear_redraw(sdlffcd_AppContext* app) {
    if (!app) return false;
    bool req = app->need_redraw;
    app->need_redraw = false;
    return req;
}

void sdlffcd_app_set_need_redraw(sdlffcd_AppContext* app, bool need_redraw) {
    if (app) {
        app->need_redraw = need_redraw;
    }
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

#include <libavutil/imgutils.h>

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

bool sdlffcd_video_seek(sdlffcd_VideoContext* vctx, double target_pts_seconds) {
    if (!vctx || !vctx->fmt_ctx || vctx->video_stream_idx < 0) return false;

    AVStream* vst = vctx->fmt_ctx->streams[vctx->video_stream_idx];
    int64_t target_ts = (int64_t)(target_pts_seconds / av_q2d(vst->time_base));

    if (av_seek_frame(vctx->fmt_ctx, vctx->video_stream_idx, target_ts, AVSEEK_FLAG_BACKWARD) < 0) {
        return false;
    }

    if (vctx->video_codec_ctx) {
        avcodec_flush_buffers(vctx->video_codec_ctx);
    }

    return true;
}

bool sdlffcd_video_render_frame(sdlffcd_AppContext* app, sdlffcd_VideoContext* vctx, const sdlffcd_VideoFrame* frame) {
    if (!app || !app->renderer || !vctx || !frame) return false;

    if (!vctx->texture || vctx->texture_width != frame->width || vctx->texture_height != frame->height) {
        if (vctx->texture) {
            SDL_DestroyTexture(vctx->texture);
            vctx->texture = NULL;
        }
        vctx->texture = SDL_CreateTexture(app->renderer, SDL_PIXELFORMAT_IYUV, SDL_TEXTUREACCESS_STREAMING, frame->width, frame->height);
        if (!vctx->texture) {
            fprintf(stderr, "Failed to create SDL video texture: %s\n", SDL_GetError());
            return false;
        }
        vctx->texture_width = frame->width;
        vctx->texture_height = frame->height;
    }

    if (frame->pixel_format == AV_PIX_FMT_YUV420P || frame->pixel_format == AV_PIX_FMT_YUVJ420P) {
        SDL_UpdateYUVTexture(vctx->texture, NULL,
            frame->data[0], frame->linesize[0],
            frame->data[1], frame->linesize[1],
            frame->data[2], frame->linesize[2]);
    } else {
        if (!vctx->sws_ctx) {
            vctx->sws_ctx = sws_getContext(
                frame->width, frame->height, (enum AVPixelFormat)frame->pixel_format,
                frame->width, frame->height, AV_PIX_FMT_YUV420P,
                SWS_BILINEAR, NULL, NULL, NULL);
            if (!vctx->sws_ctx) return false;

            if (av_image_alloc(vctx->sws_data, vctx->sws_linesize, frame->width, frame->height, AV_PIX_FMT_YUV420P, 1) < 0) {
                sws_freeContext(vctx->sws_ctx);
                vctx->sws_ctx = NULL;
                return false;
            }
        }

        sws_scale(vctx->sws_ctx, (const uint8_t* const*)frame->data, frame->linesize, 0, frame->height, vctx->sws_data, vctx->sws_linesize);
        SDL_UpdateYUVTexture(vctx->texture, NULL,
            vctx->sws_data[0], vctx->sws_linesize[0],
            vctx->sws_data[1], vctx->sws_linesize[1],
            vctx->sws_data[2], vctx->sws_linesize[2]);
    }

    SDL_SetRenderDrawColor(app->renderer, 0, 0, 0, 255);
    SDL_RenderClear(app->renderer);
    SDL_RenderTexture(app->renderer, vctx->texture, NULL, NULL);
    return true;
}

bool sdlffcd_video_redraw(sdlffcd_AppContext* app, sdlffcd_VideoContext* vctx) {
    if (!app || !app->renderer || !vctx) return false;
    SDL_SetRenderDrawColor(app->renderer, 0, 0, 0, 255);
    SDL_RenderClear(app->renderer);
    if (vctx->texture) {
        SDL_RenderTexture(app->renderer, vctx->texture, NULL, NULL);
    }
    return true;
}

void sdlffcd_video_close(sdlffcd_VideoContext* vctx) {
    if (!vctx) return;
    if (vctx->texture) {
        SDL_DestroyTexture(vctx->texture);
        vctx->texture = NULL;
    }
    if (vctx->sws_ctx) {
        sws_freeContext(vctx->sws_ctx);
        vctx->sws_ctx = NULL;
    }
    if (vctx->sws_data[0]) {
        av_freep(&vctx->sws_data[0]);
    }
    if (vctx->frame) av_frame_free(&vctx->frame);
    if (vctx->pkt) av_packet_free(&vctx->pkt);
    if (vctx->video_codec_ctx) avcodec_free_context(&vctx->video_codec_ctx);
    if (vctx->audio_codec_ctx) avcodec_free_context(&vctx->audio_codec_ctx);
    if (vctx->fmt_ctx) avformat_close_input(&vctx->fmt_ctx);
    free(vctx);
}

/* --- Text API Implementation --- */

void sdlffcd_app_present(sdlffcd_AppContext* app) {
    if (!app || !app->renderer) return;
    SDL_RenderPresent(app->renderer);
}

sdlffcd_Font* sdlffcd_font_open(const char* filepath, float ptsize) {
    if (!filepath || ptsize <= 0.0f) return NULL;
    TTF_Font* ttf_font = TTF_OpenFont(filepath, ptsize);
    if (!ttf_font) {
        fprintf(stderr, "Failed to open font %s: %s\n", filepath, SDL_GetError());
        return NULL;
    }
    sdlffcd_Font* font = (sdlffcd_Font*)calloc(1, sizeof(sdlffcd_Font));
    if (!font) {
        TTF_CloseFont(ttf_font);
        return NULL;
    }
    font->ttf_font = ttf_font;
    return font;
}

void sdlffcd_font_close(sdlffcd_Font* font) {
    if (!font) return;
    if (font->ttf_font) {
        TTF_CloseFont(font->ttf_font);
        font->ttf_font = NULL;
    }
    free(font);
}

sdlffcd_Text* sdlffcd_text_create(sdlffcd_AppContext* app, sdlffcd_Font* font, const char* text) {
    if (!app || !app->text_engine || !font || !font->ttf_font || !text) return NULL;
    TTF_Text* ttf_text = TTF_CreateText(app->text_engine, font->ttf_font, text, 0);
    if (!ttf_text) {
        fprintf(stderr, "Failed to create text object: %s\n", SDL_GetError());
        return NULL;
    }
    sdlffcd_Text* text_obj = (sdlffcd_Text*)calloc(1, sizeof(sdlffcd_Text));
    if (!text_obj) {
        TTF_DestroyText(ttf_text);
        return NULL;
    }
    text_obj->ttf_text = ttf_text;
    return text_obj;
}

bool sdlffcd_text_set_string(sdlffcd_Text* text_obj, const char* new_text) {
    if (!text_obj || !text_obj->ttf_text || !new_text) return false;
    return TTF_SetTextString(text_obj->ttf_text, new_text, 0);
}

bool sdlffcd_text_set_color(sdlffcd_Text* text_obj, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
    if (!text_obj || !text_obj->ttf_text) return false;
    return TTF_SetTextColor(text_obj->ttf_text, r, g, b, a);
}

bool sdlffcd_text_get_size(const sdlffcd_Text* text_obj, int* out_w, int* out_h) {
    if (!text_obj || !text_obj->ttf_text) return false;
    return TTF_GetTextSize(text_obj->ttf_text, out_w, out_h);
}

bool sdlffcd_text_draw(sdlffcd_Text* text_obj, float x, float y) {
    if (!text_obj || !text_obj->ttf_text) return false;
    return TTF_DrawRendererText(text_obj->ttf_text, x, y);
}

bool sdlffcd_text_draw_with_bg(sdlffcd_AppContext* app, sdlffcd_Text* text_obj, float x, float y, uint8_t bg_r, uint8_t bg_g, uint8_t bg_b, uint8_t bg_a, float padding) {
    if (!app || !app->renderer || !text_obj || !text_obj->ttf_text) return false;
    int w = 0, h = 0;
    if (TTF_GetTextSize(text_obj->ttf_text, &w, &h)) {
        SDL_FRect bg_rect;
        bg_rect.x = x - padding;
        bg_rect.y = y - padding;
        bg_rect.w = (float)w + 2.0f * padding;
        bg_rect.h = (float)h + 2.0f * padding;
        SDL_SetRenderDrawColor(app->renderer, bg_r, bg_g, bg_b, bg_a);
        SDL_RenderFillRect(app->renderer, &bg_rect);
    }
    return TTF_DrawRendererText(text_obj->ttf_text, x, y);
}

void sdlffcd_text_destroy(sdlffcd_Text* text_obj) {
    if (!text_obj) return;
    if (text_obj->ttf_text) {
        TTF_DestroyText(text_obj->ttf_text);
        text_obj->ttf_text = NULL;
    }
    free(text_obj);
}
