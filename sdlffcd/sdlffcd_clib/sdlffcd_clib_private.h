/// private api
#pragma once
#include <SDL3/SDL.h>
#include <stdbool.h>

struct sdlffcd_AppContext {
    SDL_Window* window;
    SDL_Renderer* renderer;
    bool running;
};

