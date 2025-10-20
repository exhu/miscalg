#include <SDL3/SDL_events.h>
#include <SDL3/SDL_init.h>
#include <SDL3/SDL_video.h>
#include <stdio.h>

#define PROJECT_NAME "sdlffc"

int main(int argc, char **argv) {
  if (argc != 1) {
    printf("%s takes no arguments.\n", argv[0]);
    return 1;
  }
  printf("This is project %s.\n", PROJECT_NAME);

  SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO);
  SDL_CreateWindow("hello sdl!", 1280, 720, SDL_WINDOW_OPENGL);
  SDL_Event event;
  while (SDL_WaitEvent(&event)) {
    if (event.type == SDL_EVENT_QUIT)
      break;
  }

  SDL_Quit();
  return 0;
}
