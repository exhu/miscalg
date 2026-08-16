/// private api for sdlffcd_sdl
#pragma once
#include "sdlffcd_sdl.h"

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
    sdlffcd_WindowEventCallback window_event_callback;
    void* window_event_callback_userdata;
};

struct sdlffcd_Font {
    TTF_Font* ttf_font;
};

struct sdlffcd_Text {
    TTF_Text* ttf_text;
};

struct sdlffcd_VideoRenderer {
    SDL_Texture* texture;
    int texture_width;
    int texture_height;
    int last_render_w;
    int last_render_h;
    SDL_FRect dst_rect;
};

struct sdlffcd_AudioStream {
    SDL_AudioStream* stream;
    float volume;
    uint8_t _pad[4];
};
