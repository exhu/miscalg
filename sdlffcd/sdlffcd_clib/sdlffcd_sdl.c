#include "sdlffcd_sdl.h"
#include "sdlffcd_sdl_private.h"

#include <stdio.h>
#include <stdlib.h>

static bool SDLCALL window_event_watch(void* userdata, SDL_Event* event) {
    sdlffcd_AppContext* app = (sdlffcd_AppContext*)userdata;
    if (!app || !event) return true;
    if (event->type == SDL_EVENT_WINDOW_RESIZED ||
        event->type == SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED ||
        event->type == SDL_EVENT_WINDOW_EXPOSED ||
        event->type == SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED) {
        app->need_redraw = true;
    }
    return true;
}

sdlffcd_AppContext* sdlffcd_app_init(const char* title, int width, int height) {
    if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Failed to initialize SDL: %s", SDL_GetError());
        return NULL;
    }

    sdlffcd_AppContext* app = (sdlffcd_AppContext*)calloc(1, sizeof(sdlffcd_AppContext));
    if (!app) {
        SDL_Quit();
        return NULL;
    }

    app->window = SDL_CreateWindow(title, width, height, SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY);
    if (!app->window) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Failed to create SDL window: %s", SDL_GetError());
        free(app);
        SDL_Quit();
        return NULL;
    }

    app->renderer = SDL_CreateRenderer(app->window, NULL);
    if (!app->renderer) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Failed to create SDL renderer: %s", SDL_GetError());
        SDL_DestroyWindow(app->window);
        free(app);
        SDL_Quit();
        return NULL;
    }

    if (!TTF_Init()) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Failed to initialize SDL_ttf: %s", SDL_GetError());
        SDL_DestroyRenderer(app->renderer);
        SDL_DestroyWindow(app->window);
        free(app);
        SDL_Quit();
        return NULL;
    }

    app->text_engine = TTF_CreateRendererTextEngine(app->renderer);
    if (!app->text_engine) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Failed to create renderer text engine: %s", SDL_GetError());
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
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Failed to register custom wake event: %s", SDL_GetError());
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

void sdlffcd_app_set_window_event_callback(sdlffcd_AppContext* app, sdlffcd_WindowEventCallback cb, void* userdata) {
    if (!app) return;
    app->window_event_callback = cb;
    app->window_event_callback_userdata = userdata;
}

static void process_single_event(sdlffcd_AppContext* app, const SDL_Event* event) {
    if (!app || !event) return;
    if (event->type == SDL_EVENT_QUIT) {
        app->running = false;
    } else if (event->type == SDL_EVENT_WINDOW_RESIZED ||
               event->type == SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED ||
               event->type == SDL_EVENT_WINDOW_EXPOSED ||
               event->type == SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED) {
        app->need_redraw = true;
        if (app->window_event_callback) {
            if (event->type == SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED) {
                app->window_event_callback(app->window_event_callback_userdata, SDLFFCD_WINDOW_EVENT_PIXEL_SIZE_CHANGED);
            } else if (event->type == SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED) {
                app->window_event_callback(app->window_event_callback_userdata, SDLFFCD_WINDOW_EVENT_DISPLAY_SCALE_CHANGED);
            }
        }
    } else if (event->type == SDL_EVENT_KEY_DOWN) {
        if (app->key_callback) {
            uint32_t key = (uint32_t)event->key.key;
            /* Normalize uppercase character key codes to lowercase for consistent key mapping */
            if (key >= 'A' && key <= 'Z') {
                key += ('a' - 'A');
            }
            uint16_t mod = SDLFFCD_KMOD_NONE;
            if (event->key.mod & SDL_KMOD_SHIFT) {
                mod |= SDLFFCD_KMOD_SHIFT;
            }
            if (event->key.mod & SDL_KMOD_CTRL) {
                mod |= SDLFFCD_KMOD_CTRL;
            }
            if (event->key.mod & SDL_KMOD_ALT) {
                mod |= SDLFFCD_KMOD_ALT;
            }
            app->key_callback(app->key_callback_userdata, key, mod);
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

void sdlffcd_app_present(sdlffcd_AppContext* app) {
    if (!app || !app->renderer) return;
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

bool sdlffcd_app_get_window_size(const sdlffcd_AppContext* app, int* out_w, int* out_h) {
    if (!app || !app->window || !out_w || !out_h) return false;
    return SDL_GetWindowSize(app->window, out_w, out_h);
}

float sdlffcd_app_get_display_scale(const sdlffcd_AppContext* app) {
    if (!app || !app->window) return 1.0f;
    float scale = SDL_GetWindowDisplayScale(app->window);
    return (scale > 0.0f) ? scale : 1.0f;
}

bool sdlffcd_app_toggle_fullscreen(sdlffcd_AppContext* app) {
    if (!app || !app->window) return false;
    SDL_WindowFlags flags = SDL_GetWindowFlags(app->window);
    bool is_fullscreen = (flags & SDL_WINDOW_FULLSCREEN) != 0;
    return SDL_SetWindowFullscreen(app->window, !is_fullscreen);
}

bool sdlffcd_app_is_fullscreen(const sdlffcd_AppContext* app) {
    if (!app || !app->window) return false;
    return (SDL_GetWindowFlags(app->window) & SDL_WINDOW_FULLSCREEN) != 0;
}

/* --- Video Renderer Implementation --- */

static void sdlffcd_update_letterbox_rect(SDL_Renderer* renderer, sdlffcd_VideoRenderer* vr, int src_w, int src_h) {
    int out_w = 0, out_h = 0;
    SDL_GetCurrentRenderOutputSize(renderer, &out_w, &out_h);

    if (out_w == vr->last_render_w && out_h == vr->last_render_h &&
        (vr->dst_rect.w > 0.0f || vr->dst_rect.h > 0.0f)) {
        return;
    }

    vr->last_render_w = out_w;
    vr->last_render_h = out_h;

    SDL_FRect dst = {0.0f, 0.0f, (float)out_w, (float)out_h};
    if (src_w > 0 && src_h > 0 && out_w > 0 && out_h > 0) {
        float src_aspect = (float)src_w / (float)src_h;
        float dst_aspect = (float)out_w / (float)out_h;

        if (src_aspect > dst_aspect) {
            /* Video is wider than window -> letterbox (bars top & bottom) */
            dst.w = (float)out_w;
            dst.h = (float)out_w / src_aspect;
            dst.x = 0.0f;
            dst.y = ((float)out_h - dst.h) * 0.5f;
        } else {
            /* Video is taller than window -> pillarbox (bars left & right) */
            dst.h = (float)out_h;
            dst.w = (float)out_h * src_aspect;
            dst.x = ((float)out_w - dst.w) * 0.5f;
            dst.y = 0.0f;
        }
    }
    vr->dst_rect = dst;
}

sdlffcd_VideoRenderer* sdlffcd_video_renderer_create(sdlffcd_AppContext* app) {
    (void)app;
    sdlffcd_VideoRenderer* vr = (sdlffcd_VideoRenderer*)calloc(1, sizeof(sdlffcd_VideoRenderer));
    return vr;
}

bool sdlffcd_video_renderer_draw_yuv(sdlffcd_AppContext* app, sdlffcd_VideoRenderer* vr,
                                    const uint8_t* const data[8], const int linesize[8],
                                    int width, int height) {
    if (!app || !app->renderer || !vr || !data || width <= 0 || height <= 0) return false;

    if (!vr->texture || vr->texture_width != width || vr->texture_height != height) {
        if (vr->texture) {
            SDL_DestroyTexture(vr->texture);
            vr->texture = NULL;
        }
        vr->texture = SDL_CreateTexture(app->renderer, SDL_PIXELFORMAT_IYUV, SDL_TEXTUREACCESS_STREAMING, width, height);
        if (!vr->texture) {
            SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Failed to create SDL video texture: %s", SDL_GetError());
            return false;
        }
        vr->texture_width = width;
        vr->texture_height = height;
    }

    SDL_UpdateYUVTexture(vr->texture, NULL,
        data[0], linesize[0],
        data[1], linesize[1],
        data[2], linesize[2]);

    SDL_SetRenderDrawColor(app->renderer, 0, 0, 0, 255);
    SDL_RenderClear(app->renderer);
    sdlffcd_update_letterbox_rect(app->renderer, vr, vr->texture_width, vr->texture_height);
    SDL_RenderTexture(app->renderer, vr->texture, NULL, &vr->dst_rect);
    return true;
}

bool sdlffcd_video_renderer_redraw(sdlffcd_AppContext* app, sdlffcd_VideoRenderer* vr) {
    if (!app || !app->renderer || !vr) return false;
    SDL_SetRenderDrawColor(app->renderer, 0, 0, 0, 255);
    SDL_RenderClear(app->renderer);
    if (vr->texture) {
        sdlffcd_update_letterbox_rect(app->renderer, vr, vr->texture_width, vr->texture_height);
        SDL_RenderTexture(app->renderer, vr->texture, NULL, &vr->dst_rect);
    }
    return true;
}

void sdlffcd_video_renderer_destroy(sdlffcd_VideoRenderer* vr) {
    if (!vr) return;
    if (vr->texture) {
        SDL_DestroyTexture(vr->texture);
        vr->texture = NULL;
    }
    free(vr);
}

/* --- Audio Stream Playback Implementation --- */

sdlffcd_AudioStream* sdlffcd_audio_stream_open(int sample_rate, int channels) {
    if (sample_rate <= 0 || channels <= 0) return NULL;
    SDL_AudioSpec spec;
    spec.format = SDL_AUDIO_S16;
    spec.channels = channels;
    spec.freq = sample_rate;
    SDL_AudioStream* stream = SDL_OpenAudioDeviceStream(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &spec, NULL, NULL);
    if (!stream) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Failed to open SDL audio device stream: %s", SDL_GetError());
        return NULL;
    }
    sdlffcd_AudioStream* as = (sdlffcd_AudioStream*)calloc(1, sizeof(sdlffcd_AudioStream));
    if (!as) {
        SDL_DestroyAudioStream(stream);
        return NULL;
    }
    as->stream = stream;
    as->volume = 1.0f;
    SDL_SetAudioStreamGain(as->stream, as->volume);
    return as;
}

bool sdlffcd_audio_stream_put_data(sdlffcd_AudioStream* stream, const void* data, int len) {
    if (!stream || !stream->stream || !data || len <= 0) return false;
    return SDL_PutAudioStreamData(stream->stream, data, len);
}

bool sdlffcd_audio_stream_set_paused(sdlffcd_AudioStream* stream, bool paused) {
    if (!stream || !stream->stream) return false;
    if (paused) {
        return SDL_PauseAudioStreamDevice(stream->stream);
    } else {
        return SDL_ResumeAudioStreamDevice(stream->stream);
    }
}

bool sdlffcd_audio_stream_is_paused(const sdlffcd_AudioStream* stream) {
    if (!stream || !stream->stream) return true;
    return SDL_AudioStreamDevicePaused(stream->stream);
}

bool sdlffcd_audio_stream_clear(sdlffcd_AudioStream* stream) {
    if (!stream || !stream->stream) return false;
    return SDL_ClearAudioStream(stream->stream);
}

bool sdlffcd_audio_stream_set_volume(sdlffcd_AudioStream* stream, float volume) {
    if (!stream) return false;
    if (volume < 0.0f) volume = 0.0f;
    if (volume > 1.0f) volume = 1.0f;
    stream->volume = volume;
    if (stream->stream) {
        return SDL_SetAudioStreamGain(stream->stream, volume);
    }
    return true;
}

bool sdlffcd_audio_stream_get_volume(const sdlffcd_AudioStream* stream, float* out_volume) {
    if (!stream || !out_volume) return false;
    *out_volume = stream->volume;
    return true;
}

void sdlffcd_audio_stream_close(sdlffcd_AudioStream* stream) {
    if (!stream) return;
    if (stream->stream) {
        SDL_DestroyAudioStream(stream->stream);
        stream->stream = NULL;
    }
    free(stream);
}

/* --- Text & Font Implementation --- */

sdlffcd_Font* sdlffcd_font_open(const void* data, size_t data_size, float ptsize) {
    if (!data || data_size == 0 || ptsize <= 0.0f) return NULL;
    SDL_IOStream* io = SDL_IOFromConstMem(data, data_size);
    if (!io) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Failed to create SDL_IOStream for font: %s", SDL_GetError());
        return NULL;
    }
    TTF_Font* ttf_font = TTF_OpenFontIO(io, true, ptsize);
    if (!ttf_font) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Failed to open font from memory: %s", SDL_GetError());
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

bool sdlffcd_font_set_hinting(sdlffcd_Font* font, sdlffcd_FontHinting hinting) {
    if (!font || !font->ttf_font) return false;
    TTF_SetFontHinting(font->ttf_font, (TTF_HintingFlags)hinting);
    return true;
}

sdlffcd_FontHinting sdlffcd_font_get_hinting(const sdlffcd_Font* font) {
    if (!font || !font->ttf_font) return SDLFFCD_FONT_HINTING_NORMAL;
    return (sdlffcd_FontHinting)TTF_GetFontHinting(font->ttf_font);
}

bool sdlffcd_font_set_size_dpi(sdlffcd_Font* font, float ptsize, int hdpi, int vdpi) {
    if (!font || !font->ttf_font || ptsize <= 0.0f) return false;
    return TTF_SetFontSizeDPI(font->ttf_font, ptsize, hdpi, vdpi);
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
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Failed to create text object: %s", SDL_GetError());
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

bool sdlffcd_text_draw_with_bg(sdlffcd_AppContext* app, sdlffcd_Text* text_obj, float x, float y,
                               uint8_t bg_r, uint8_t bg_g, uint8_t bg_b, uint8_t bg_a, float padding) {
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

/* --- Log API Implementation --- */

void sdlffcd_log_message(int category, sdlffcd_LogPriority priority, const char* message) {
    if (!message) return;
    SDL_LogMessage(category, (SDL_LogPriority)priority, "%s", message);
}

void sdlffcd_log_set_all_priority(sdlffcd_LogPriority priority) {
    SDL_SetLogPriorities((SDL_LogPriority)priority);
}
