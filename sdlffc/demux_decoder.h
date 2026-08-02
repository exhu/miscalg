#pragma once
#include "sdlffclib_private.h"
#include "sdlffclib.h"

/// Free ffmpeg decoder resources
void sdlffclib_free_video_file_ctx(SdlffVideoFileContext *ctx);

/// Read next packet from container and decode audio/video frames
void read_and_decode_next_packet(SdlffContext *context);
