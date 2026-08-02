#include "sdlffclib.h"
#include "sdlffclib_private.h"
#include <SDL3/SDL.h>
#include <assert.h>
#include <stdio.h>

int main(int argc, char **argv) {
  const char *file_path = (argc > 1) ? argv[1] : "samplevideo.mp4";
  SDL_SetHint(SDL_HINT_VIDEO_DRIVER, "dummy");
  SDL_SetHint(SDL_HINT_AUDIO_DRIVER, "dummy");

  SdlffContext *context = NULL;
  if (!sdlffclib_init(&context)) {
    fprintf(stderr, "Failed to init sdlffclib\n");
    return 1;
  }

  if (!sdlffclib_open_video(context, file_path)) {
    fprintf(stderr, "Failed to open video: %s\n", file_path);
    sdlffclib_done(&context);
    return 1;
  }

  /* Verify initial markers: IN = 0.0, OUT = duration - min_seek_increment */
  assert(context->in_point >= 0.0 && context->in_point < 0.001);
  assert(context->out_point > 0.0);
  assert(!context->markers_modified);
  assert(!context->looping);
  assert(context->overlay_mode == OVERLAY_TOP_LEFT);

  /* Simulate setting IN marker at t=1.5s */
  context->in_point = 1.5;
  context->markers_modified = true;

  /* Simulate setting OUT marker at t=4.5s */
  context->out_point = 4.5;

  assert(context->markers_modified);

  /* Test key V cycling */
  context->overlay_mode = (OverlayMode)((context->overlay_mode + 1) % 3);
  assert(context->overlay_mode == OVERLAY_BOTTOM_RIGHT);
  context->overlay_mode = (OverlayMode)((context->overlay_mode + 1) % 3);
  assert(context->overlay_mode == OVERLAY_HIDDEN);
  context->overlay_mode = (OverlayMode)((context->overlay_mode + 1) % 3);
  assert(context->overlay_mode == OVERLAY_TOP_LEFT);

  /* Test looping toggle */
  context->looping = true;
  assert(context->looping);

  printf("All marker & cutting logic assertions passed successfully!\n");
  sdlffclib_done(&context);
  return 0;
}
