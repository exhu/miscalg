#pragma once
#include "sdlffclib_private.h"

/// Called on MAIN thread: create/reuse texture, convert frame via sws_scale
/// into the locked CPU buffer, upload to GPU, and render.
void render_frame_main_thread(SdlffContext *context, AVFrame *frame);

/// Re-renders the current frame texture and timestamp overlay on the main thread.
void redraw_current_frame(SdlffContext *context);
