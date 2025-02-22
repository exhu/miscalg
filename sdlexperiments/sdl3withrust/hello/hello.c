#include <SDL3/SDL.h>
//#include <SDL3/SDL_main.h>

/* We will use this renderer to draw into this window every frame. */
static SDL_Window *window = NULL;
static SDL_Renderer *renderer = NULL;

extern void rust_hello();

int main(int argc, char* argv[]) {

  SDL_Log("%s", "hello from mysdl");
  rust_hello();
  return 0;
}
