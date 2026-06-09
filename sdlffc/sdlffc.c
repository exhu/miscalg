#include "sdlffclib.h"
#include <stdio.h>

#define PROJECT_NAME "sdlffc"

int main(int argc, char **argv) {
  if (argc != 2) {
    printf("%s requires argument: file name of a video file\n", argv[0]);
    return 1;
  }
  printf("This is project %s.\n", PROJECT_NAME);
  SdlffContext* context = NULL;
  if (sdlffclib_init(&context)) {
    const char * file_path = argv[1];
    sdlffclib_fileinfo(file_path);
    sdlffclib_open_video(context, file_path);
    sdlffclib_main_loop(context);
  }
  sdlffclib_done(&context);

  return 0;
}
