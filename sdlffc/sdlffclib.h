#pragma once
#include <stdbool.h>

struct _SdlffContext;
typedef struct _SdlffContext SdlffContext;

/// NOTE: can be called only once (reuses global state).
bool sdlffclib_init(SdlffContext **out_context);
void sdlffclib_done(SdlffContext **out_context);
void sdlffclib_main_loop(SdlffContext *context);

// video/media section
/// dumps file info to log
bool sdlffclib_fileinfo(const char *file_path);
