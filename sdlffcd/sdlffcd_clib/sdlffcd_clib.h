/// public functions for D
#pragma once
#include <stdbool.h>

typedef struct AppContext AppContext;

/// Initialize SDL3, create window and renderer. Returns NULL on failure.
AppContext* app_init(const char* title, int width, int height);

/// Check if application is running.
bool app_is_running(const AppContext* app);

/// Wait for next event and process all queued events (blocking when idle to save CPU).
void app_wait_events(AppContext* app);

/// Clear screen and present frame
void app_render(AppContext* app);

/// Destroy window/renderer and quit SDL3.
void app_shutdown(AppContext* app);

