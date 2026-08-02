#pragma once
#include "sdlffclib_private.h"

/// notify main thread to read mailbox
void send_main_thread_event(SdlffContext *context);

/// video decoding thread entry point
int SDLCALL video_thread_cb(void *data);
