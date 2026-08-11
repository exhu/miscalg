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

