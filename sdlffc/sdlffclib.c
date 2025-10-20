#include <SDL3/SDL_events.h>
#include <SDL3/SDL_init.h>
#include <SDL3/SDL_video.h>

bool sdlffclib_init() {
  if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO))
    return false;
  
  SDL_Window* window = SDL_CreateWindow("hello sdl!", 1280, 720, SDL_WINDOW_OPENGL);
  return window != NULL;
}

void sdlffclib_main_loop() {
  SDL_Event event;
  while (SDL_WaitEvent(&event)) {
    if (event.type == SDL_EVENT_QUIT)
      break;
  }

  SDL_Quit();
}
