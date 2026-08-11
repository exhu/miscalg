/// public functions for D
#pragma once
#include <stdbool.h>

typedef struct sdlffcd_AppContext sdlffcd_AppContext;

/// Initialize SDL3, create window and renderer. Returns NULL on failure.
sdlffcd_AppContext* sdlffcd_app_init(const char* title, int width, int height);

/// Check if application is running.
bool sdlffcd_app_is_running(const sdlffcd_AppContext* app);

/// Wait for next event and process all queued events (blocking when idle to save CPU).
void sdlffcd_app_wait_events(sdlffcd_AppContext* app);

/// Clear screen and present frame
void sdlffcd_app_render(sdlffcd_AppContext* app);

/// Destroy window/renderer and quit SDL3.
void sdlffcd_app_shutdown(sdlffcd_AppContext* app);


