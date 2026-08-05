#include "sdlffclib.h"
#include "sdlffclib_private.h"
#include <SDL3/SDL.h>
#include <assert.h>
#include <stdio.h>

static Uint32 SDLCALL space1_cb(void *userdata, SDL_TimerID timerID, Uint32 interval) {
  (void)timerID; (void)interval; (void)userdata;
  printf("[TEST STEP 1] Pressing Space after stream end...\n");
  SDL_Event event; SDL_zero(event);
  event.type = SDL_EVENT_KEY_DOWN;
  event.key.key = SDLK_SPACE;
  event.key.down = true;
  SDL_PushEvent(&event);
  return 0;
}

static Uint32 SDLCALL space2_cb(void *userdata, SDL_TimerID timerID, Uint32 interval) {
  (void)timerID; (void)interval; (void)userdata;
  printf("[TEST STEP 2] Pressing Space again after stream end...\n");
  SDL_Event event; SDL_zero(event);
  event.type = SDL_EVENT_KEY_DOWN;
  event.key.key = SDLK_SPACE;
  event.key.down = true;
  SDL_PushEvent(&event);
  return 0;
}

static Uint32 SDLCALL rewind_cb(void *userdata, SDL_TimerID timerID, Uint32 interval) {
  (void)timerID; (void)interval; (void)userdata;
  printf("[TEST STEP 3] Rewinding (-5s) via Left Arrow...\n");
  SDL_Event event; SDL_zero(event);
  event.type = SDL_EVENT_KEY_DOWN;
  event.key.key = SDLK_LEFT;
  event.key.down = true;
  SDL_PushEvent(&event);
  return 0;
}

static Uint32 SDLCALL quit_cb(void *userdata, SDL_TimerID timerID, Uint32 interval) {
  (void)timerID; (void)interval; (void)userdata;
  printf("[TEST STEP 4] Quitting...\n");
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

  context->exit_at_end = false;

  if (!sdlffclib_open_video(context, file_path)) {
    fprintf(stderr, "Failed to open video: %s\n", file_path);
    sdlffclib_done(&context);
    return 1;
  }

  /* samplevideo.mp4 is ~8.9s. Stream end will be reached around t=9s.
     Schedule Space press at t=10s, Space press at t=11s, Rewind at t=12s, Quit at t=15s */
  SDL_AddTimer(10000, space1_cb, context);
  SDL_AddTimer(11000, space2_cb, context);
  SDL_AddTimer(12000, rewind_cb, context);
  SDL_AddTimer(15000, quit_cb, context);

  printf("Starting test_stream_end_pause...\n");
  sdlffclib_main_loop(context);

  assert(context->stream_ended == false);
  printf("Main loop finished successfully.\n");
  sdlffclib_done(&context);
  return 0;
}
