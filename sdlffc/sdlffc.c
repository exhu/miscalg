#include "sdlffclib.h"
#include <stdio.h>
#include <string.h>

#define PROJECT_NAME "sdlffc"

static void print_usage(const char *prog_name) {
  printf("Usage: %s [OPTIONS] <video_file>\n\n", prog_name);
  printf("An SDL3 + FFmpeg video player with frame-accurate cutting & looping.\n\n");
  printf("Options:\n");
  printf("  -h, --help    Display this help message and exit\n\n");
  printf("Keyboard Shortcuts:\n");
  printf("  Space         Pause / Resume video playback\n");
  printf("  Left / Right  Seek backward / forward by 5 seconds\n");
  printf("  [ / ]         Step 1 frame backward / forward (pauses if playing)\n");
  printf("  B             Seek to video start frame (00:00:00)\n");
  printf("  E             Seek to video end frame\n");
  printf("  I             Set IN-marker (start of cut) to current frame time\n");
  printf("  O             Set OUT-marker (last frame of cut) to current frame time\n");
  printf("  Shift + I     Seek to IN-marker position\n");
  printf("  Shift + O     Seek to OUT-marker position\n");
  printf("  L             Toggle looping between IN and OUT markers\n");
  printf("  V             Cycle overlay position (Top-Left -> Bottom-Right -> Hidden)\n");
  printf("  Enter         Print lossless FFmpeg cut command to stdout\n");
  printf("  Ctrl + Enter  Execute FFmpeg export command asynchronously\n");
  printf("  Q / Esc       Quit application (auto-prints FFmpeg command if markers modified)\n");
}

int main(int argc, char **argv) {
  if (argc != 2) {
    print_usage(argv[0]);
    return (argc > 1) ? 0 : 1;
  }

  if (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0) {
    print_usage(argv[0]);
    return 0;
  }

  SdlffContext* context = NULL;
  if (sdlffclib_init(&context)) {
    const char * file_path = argv[1];
    sdlffclib_fileinfo(file_path);
    if (sdlffclib_open_video(context, file_path)) {
      sdlffclib_main_loop(context);
    }
  }
  sdlffclib_done(&context);
  return 0;
}
