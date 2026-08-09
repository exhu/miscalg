# Plan: SDL Window Initialization, Main Loop, and Shutdown

## Goal Description
Implement full lifecycle management (initialization, event loop processing, rendering, and shutdown) for an SDL3 window using the `sdlffcd_clib` C bridge and driven by the D application entry point in `source/app.d`.

All direct SDL3 library interactions will be encapsulated within `sdlffcd_clib` C code to maintain clean boundaries and minimize D binding overhead.

---

## Architecture Overview

```mermaid
flowchart TD
    subgraph D Code
        A["source/app.d (main)"] -->|"Calls lifecycle functions"| B["source/sdlffcd_clib.d (extern C)"]
    end
    subgraph C Bridge Library (sdlffcd_clib)
        B -->|"C ABI"| C["sdlffcd_clib.h / sdlffcd_clib.c"]
        C -->|"Manages"| D["AppContext (window, renderer, running state)"]
        C -->|"SDL3 API"| E["libsdl3"]
    end
```

---

## User Review Required

> [!IMPORTANT]
> To prevent CPU busy-polling when there are no user events, `app_wait_events` uses `SDL_WaitEvent` to block efficiently until an event arrives, instead of tight `SDL_PollEvent` looping.

---

## Proposed Changes

### Component: C Bridge (`sdlffcd_clib`)

#### [MODIFY] [`sdlffcd_clib/sdlffcd_clib_private.h`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib_private.h)
Add internal SDL window and renderer fields to `AppContext`.

```c
#pragma once
#include <SDL3/SDL.h>
#include <stdbool.h>

struct AppContext {
    SDL_Window* window;
    SDL_Renderer* renderer;
    bool running;
};
```

#### [MODIFY] [`sdlffcd_clib/sdlffcd_clib.h`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.h)
Declare public context creation, event waiting, frame rendering, and cleanup functions.

```c
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
```

#### [MODIFY] [`sdlffcd_clib/sdlffcd_clib.c`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.c)
Implement the C lifecycle functions using `SDL_WaitEvent`.

```c
#include "sdlffcd_clib.h"
#include "sdlffcd_clib_private.h"

#include <stdio.h>
#include <stdlib.h>

AppContext* app_init(const char* title, int width, int height) {
    if (!SDL_Init(SDL_INIT_VIDEO)) {
        fprintf(stderr, "Failed to initialize SDL: %s\n", SDL_GetError());
        return NULL;
    }

    AppContext* app = (AppContext*)calloc(1, sizeof(AppContext));
    if (!app) {
        SDL_Quit();
        return NULL;
    }

    app->window = SDL_CreateWindow(title, width, height, SDL_WINDOW_RESIZABLE);
    if (!app->window) {
        fprintf(stderr, "Failed to create SDL window: %s\n", SDL_GetError());
        free(app);
        SDL_Quit();
        return NULL;
    }

    app->renderer = SDL_CreateRenderer(app->window, NULL);
    if (!app->renderer) {
        fprintf(stderr, "Failed to create SDL renderer: %s\n", SDL_GetError());
        SDL_DestroyWindow(app->window);
        free(app);
        SDL_Quit();
        return NULL;
    }

    app->running = true;
    return app;
}

bool app_is_running(const AppContext* app) {
    return app && app->running;
}

void app_wait_events(AppContext* app) {
    if (!app) return;
    SDL_Event event;
    // SDL_WaitEvent blocks until an event is available, preventing high CPU busy polling
    if (SDL_WaitEvent(&event)) {
        do {
            if (event.type == SDL_EVENT_QUIT) {
                app->running = false;
            } else if (event.type == SDL_EVENT_KEY_DOWN) {
                if (event.key.key == SDLK_ESCAPE || event.key.key == SDLK_Q) {
                    app->running = false;
                }
            }
        } while (SDL_PollEvent(&event)); // process remaining events in queue
    }
}

void app_render(AppContext* app) {
    if (!app || !app->renderer) return;
    // Dark slate background
    SDL_SetRenderDrawColor(app->renderer, 30, 32, 40, 255);
    SDL_RenderClear(app->renderer);
    SDL_RenderPresent(app->renderer);
}

void app_shutdown(AppContext* app) {
    if (!app) return;
    if (app->renderer) SDL_DestroyRenderer(app->renderer);
    if (app->window) SDL_DestroyWindow(app->window);
    SDL_Quit();
    free(app);
}
```

---

### Component: D Application (`source`)

#### [MODIFY] [`source/sdlffcd_clib.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/sdlffcd_clib.d)
Expose exact matching C bindings to D.

```d
extern(C):

struct AppContext;

AppContext* app_init(const char* title, int width, int height);
bool app_is_running(const AppContext* app);
void app_wait_events(AppContext* app);
void app_render(AppContext* app);
void app_shutdown(AppContext* app);
```

#### [MODIFY] [`source/app.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/app.d)
Implement the main loop in D.

```d
import std.stdio;
import sdlffcd_clib;

void main()
{
    writeln("Initializing SDL application...");
    AppContext* app = app_init("sdlffcd - Video Player", 800, 600);
    if (app is null)
    {
        stderr.writeln("Failed to initialize application context.");
        return;
    }

    // Initial render
    app_render(app);

    writeln("Entering main loop (waiting for events)...");
    while (app_is_running(app))
    {
        app_wait_events(app);
        app_render(app);
    }

    writeln("Shutting down application...");
    app_shutdown(app);
    writeln("Exited cleanly.");
}
```

---

## Verification Plan

### Automated Build Verification
1. Run `dub build` to ensure Meson recompiles `libsdlffcd_clib.a` and D compiler links the executable smoothly:
   ```bash
   export PKG_CONFIG_PATH="$HOME/.local/lib/pkgconfig:$PKG_CONFIG_PATH" && dub build
   ```

### Manual Verification
1. Run `./sdlffcd` (or `dub run`):
   - Verify window titled `"sdlffcd - Video Player"` opens with dimensions 800x600.
   - Verify CPU usage is ~0% while idle (waiting for events).
   - Verify window close button (`X`) or pressing `Esc` / `Q` key exits main loop cleanly.
   - Confirm stdout prints initialization and clean exit messages.
