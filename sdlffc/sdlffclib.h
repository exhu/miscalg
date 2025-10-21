#pragma once
#include <stdbool.h>

struct _SdlffContext;
typedef struct _SdlffContext SdlffContext;

bool sdlffclib_init(SdlffContext **out_context);
void sdlffclib_done(SdlffContext **out_context);
void sdlffclib_main_loop(SdlffContext *context);
