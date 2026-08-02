#include "sdlffclib.h"
#include "sdlffclib_private.h"
#include <SDL3/SDL.h>
#include <assert.h>
#include <math.h>
#include <stdio.h>

static Uint32 SDLCALL left_bracket_cb(void *userdata, SDL_TimerID timerID, Uint32 interval) {
  (void)timerID; (void)interval; (void)userdata;
  printf("[TEST STEP 1] Pressing '[' (SDLK_LEFTBRACKET) during active playback...\n");
  SDL_Event event; SDL_zero(event);
  event.type = SDL_EVENT_KEY_DOWN;
  event.key.key = SDLK_LEFTBRACKET;
  event.key.down = true;
  SDL_PushEvent(&event);
  return 0;
}

static Uint32 SDLCALL right_bracket_cb(void *userdata, SDL_TimerID timerID, Uint32 interval) {
  (void)timerID; (void)interval; (void)userdata;
  printf("[TEST STEP 2] Pressing ']' (SDLK_RIGHTBRACKET) while paused...\n");
  SDL_Event event; SDL_zero(event);
  event.type = SDL_EVENT_KEY_DOWN;
  event.key.key = SDLK_RIGHTBRACKET;
  event.key.down = true;
  SDL_PushEvent(&event);
  return 0;
}

static Uint32 SDLCALL quit_cb(void *userdata, SDL_TimerID timerID, Uint32 interval) {
  (void)timerID; (void)interval; (void)userdata;
  printf("[TEST STEP 3] Quitting...\n");
  SDL_Event event; SDL_zero(event);
  event.type = SDL_EVENT_KEY_DOWN;
  event.key.key = SDLK_Q;
  event.key.down = true;
  SDL_PushEvent(&event);
  return 0;
}

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

  /* Test min seek increment calculation and caching */
  double min_inc = sdlffclib_get_min_seek_increment(context);
  printf("Calculated min seek increment: %f seconds (cached: %f)\n",
         min_inc, context->min_seek_increment);

  assert(min_inc > 0.0);
  assert(fabs(min_inc - context->min_seek_increment) < 1e-6);
  assert(fabs(min_inc - (1.0 / 30.0)) < 1e-3); /* samplevideo.mp4 is 30 fps */

  /* Schedule key events */
  SDL_AddTimer(1000, left_bracket_cb, context);  /* Press '[' at t=1s */
  SDL_AddTimer(2000, right_bracket_cb, context); /* Press ']' at t=2s */
  SDL_AddTimer(3000, quit_cb, context);          /* Quit at t=3s */

  printf("Starting test_frame_seek main loop...\n");
  sdlffclib_main_loop(context);

  assert(context->paused == true); /* should be paused after bracket key seek */
  printf("Frame seek test passed successfully.\n");
  sdlffclib_done(&context);
  return 0;
}
