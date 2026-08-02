#include "sdlffclib.h"
#include "sdlffclib_private.h"
#include <SDL3/SDL.h>
#include <assert.h>
#include <stdio.h>

static Uint32 SDLCALL pause_cb(void *userdata, SDL_TimerID timerID, Uint32 interval) {
  (void)timerID; (void)interval; (void)userdata;
  printf("[TEST STEP 1] Pausing playback at t=2s (Space)...\n");
  SDL_Event event; SDL_zero(event);
  event.type = SDL_EVENT_KEY_DOWN;
  event.key.key = SDLK_SPACE;
  event.key.down = true;
  SDL_PushEvent(&event);
  return 0;
}

static Uint32 SDLCALL seek1_cb(void *userdata, SDL_TimerID timerID, Uint32 interval) {
  (void)timerID; (void)interval; (void)userdata;
  printf("[TEST STEP 2] Seeking -1s while paused (Left Arrow)...\n");
  SDL_Event event; SDL_zero(event);
  event.type = SDL_EVENT_KEY_DOWN;
  event.key.key = SDLK_LEFT;
  event.key.down = true;
  SDL_PushEvent(&event);
  return 0;
}

static Uint32 SDLCALL seek2_cb(void *userdata, SDL_TimerID timerID, Uint32 interval) {
  (void)timerID; (void)interval; (void)userdata;
  printf("[TEST STEP 3] Seeking +4s while paused (Right Arrow)...\n");
  SDL_Event event; SDL_zero(event);
  event.type = SDL_EVENT_KEY_DOWN;
  event.key.key = SDLK_RIGHT;
  event.key.down = true;
  SDL_PushEvent(&event);
  return 0;
}

static Uint32 SDLCALL resume_cb(void *userdata, SDL_TimerID timerID, Uint32 interval) {
  (void)timerID; (void)interval; (void)userdata;
  printf("[TEST STEP 4] Resuming playback (Space)...\n");
  SDL_Event event; SDL_zero(event);
  event.type = SDL_EVENT_KEY_DOWN;
  event.key.key = SDLK_SPACE;
  event.key.down = true;
  SDL_PushEvent(&event);
  return 0;
}

static Uint32 SDLCALL quit_cb(void *userdata, SDL_TimerID timerID, Uint32 interval) {
  (void)timerID; (void)interval; (void)userdata;
  printf("[TEST STEP 5] Quitting (Q)...\n");
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

  /* Schedule test actions */
  SDL_AddTimer(2000, pause_cb, context);   /* Pause at t=2s */
  SDL_AddTimer(4000, seek1_cb, context);   /* Seek -1s at t=4s (while paused) */
  SDL_AddTimer(6000, seek2_cb, context);   /* Seek +4s at t=6s (while paused) */
  SDL_AddTimer(8000, resume_cb, context);  /* Resume at t=8s */
  SDL_AddTimer(12000, quit_cb, context);   /* Quit at t=12s */

  printf("Starting test_pause_seek...\n");
  sdlffclib_main_loop(context);

  printf("Main loop finished.\n");
  sdlffclib_done(&context);
  return 0;
}
