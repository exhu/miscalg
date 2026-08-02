#include "sdlffclib.h"
#include "sdlffclib_private.h"
#include <SDL3/SDL.h>
#include <assert.h>
#include <stdio.h>

static Uint32 SDLCALL push_left_key_cb(void *userdata, SDL_TimerID timerID, Uint32 interval) {
  (void)timerID; (void)interval;
  (void)userdata;
  printf("[TEST TIMER] Pushing SDLK_LEFT key event...\n");
  SDL_Event event;
  SDL_zero(event);
  event.type = SDL_EVENT_KEY_DOWN;
  event.key.key = SDLK_LEFT;
  SDL_PushEvent(&event);
  return 0;
}

static Uint32 SDLCALL push_quit_key_cb(void *userdata, SDL_TimerID timerID, Uint32 interval) {
  (void)userdata; (void)timerID; (void)interval;
  printf("[TEST TIMER] Pushing SDLK_Q key event...\n");
  SDL_Event event;
  SDL_zero(event);
  event.type = SDL_EVENT_KEY_DOWN;
  event.key.key = SDLK_Q;
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

  /* Schedule rewind key press at 10 seconds (after video ended at 8.9s) */
  SDL_AddTimer(10000, push_left_key_cb, context);
  /* Schedule quit key press at 13 seconds (after rewind resumed playback) */
  SDL_AddTimer(13000, push_quit_key_cb, context);

  printf("Running main loop with exit_at_end = false...\n");
  sdlffclib_main_loop(context);

  printf("Main loop exited cleanly after rewind test.\n");
  sdlffclib_done(&context);
  return 0;
}
