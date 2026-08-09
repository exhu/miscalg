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

    // Initial frame render
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

