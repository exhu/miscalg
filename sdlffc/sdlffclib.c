#include "sdlffclib.h"
#include <SDL3/SDL_events.h>
#include <SDL3/SDL_init.h>
#include <SDL3/SDL_render.h>
#include <SDL3/SDL_video.h>

#include <malloc.h>

typedef struct _SdlffContext {
  SDL_Window *window;
  SDL_Renderer *renderer;
} SdlffContext;

bool sdlffclib_init(SdlffContext **out_context) {
  if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO))
    return false;

  SdlffContext *context = malloc(sizeof(SdlffContext));
  *out_context = context;

  return SDL_CreateWindowAndRenderer("hello sdl!", 1280, 720, 0,
                                     &context->window, &context->renderer);
}

void sdlffclib_done(SdlffContext **out_context) {
  SDL_DestroyRenderer((*out_context)->renderer);
  SDL_DestroyWindow((*out_context)->window);
  free(*out_context);
  *out_context = NULL;
  SDL_Quit();
}

void sdlffclib_main_loop(SdlffContext *context) {
  SDL_Event event;
  while (SDL_WaitEvent(&event)) {
    if (event.type == SDL_EVENT_QUIT)
      break;
    SDL_SetRenderDrawColor(context->renderer, 0x00, 0x00, 0x00, 0x00);
    SDL_RenderClear(context->renderer);
    SDL_SetRenderDrawColor(context->renderer, 0xFF, 0x00, 0x00, 0xFF);
    SDL_RenderLine(context->renderer, 0.f, 0.f, 50.f, 25.f);
    
    SDL_RenderPresent(context->renderer);
  }
}
