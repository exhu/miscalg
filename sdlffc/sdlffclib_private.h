#pragma once
#include <SDL3/SDL.h>

typedef struct _SdlffContext {
  SDL_Window *window;
  SDL_Renderer *renderer;
} SdlffContext;
