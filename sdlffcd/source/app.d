import std.stdio;
import sdlffcd_clib;

void main()
{
    writeln("Initializing SDL application...");
    sdlffcd_AppContext* app = sdlffcd_app_init("sdlffcd - Video Play&Trim", 800, 600);
    if (app is null)
    {
        stderr.writeln("Failed to initialize application context.");
        return;
    }

    // Initial frame render
    sdlffcd_app_render(app);

    writeln("Entering main loop (waiting for events)...");
    while (sdlffcd_app_is_running(app))
    {
        sdlffcd_app_wait_events(app);
        sdlffcd_app_render(app);
    }

    writeln("Shutting down application...");
    sdlffcd_app_shutdown(app);
    writeln("Exited cleanly.");
}
