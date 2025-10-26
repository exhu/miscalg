#pragma once
#include <SDL3/SDL.h>
#include <SDL3/SDL_render.h>

struct _SdlffContext {
  SDL_Window *window;
  SDL_Renderer *renderer;
  SDL_Texture *streaming_texture;
};
