sdlffcd_clib is a C99 library that helps avoid writing and keeping up to date full featured bindings to C dependencies for D application consumption.

Public D api externals (opaque structs) goes to sdlffcd_clib.h, private api (real structs) into sdlffcd_clib_private.h

It must implement some minimal chunks of logic split into C functions that would require a lot of calls to a third-party C library, e.g.
SDL window setup/shutdown, text rendering, ffmpeg libs decoding code, by wrapping them into functions that are then called from D.

Example:
D code needs to call a number of libsdl functions to setup SDL subsystems, window, renderer, register custom event...
But libsdl is a C library, so we need to define a chunk of logic and delegate
it's implementation to sdlffcd_clib. Here we can see multiple chunks of logic: initialization, destruction. Destruction would need some sort of context to store previously allocated data, so we implement a struct AppContext, that is opaque to D code, and implement an initialization
and destuction functions e.g.

sdlffcd_clib.h:

/// returns NULL on failure
AppContext* app_context_init(const char* title);
void app_context_done(AppContext *context);

sdlffcd_clib.d:
extern(C):
struct AppContext;
AppContext* app_context_init(...);
void app_context_done(AppContext* context);
