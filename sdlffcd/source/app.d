import std.stdio;
import std.string;
import core.thread;
import std.datetime;

import sdlffcd_clib;
import video_player;
import app_context;

extern(C) void handleKeyPress(void* userdata, uint key)
{
    AppContext* app = cast(AppContext*)userdata;
    if (key == sdlffcd_Key.SDLFFCD_KEY_ESCAPE ||
        key == sdlffcd_Key.SDLFFCD_KEY_Q)
    {
        writeln("Key press received in D (Q / ESCAPE). Requesting app stop...");
        if (app.app !is null)
        {
            sdlffcd_app_stop(app.app);
        }
    }
    else if (key == sdlffcd_Key.SDLFFCD_KEY_SPACE ||
             key == sdlffcd_Key.SDLFFCD_KEY_P)
    {
        if (app.player !is null)
        {
            app.player.togglePause();
        }
    }
    else if (key == sdlffcd_Key.SDLFFCD_KEY_R ||
             key == sdlffcd_Key.SDLFFCD_KEY_LEFT) // Left arrow or 'R'
    {
        if (app.player !is null)
        {
            app.player.rewind(5.0);
        }
    }
    else if (key == sdlffcd_Key.SDLFFCD_KEY_F ||
             key == sdlffcd_Key.SDLFFCD_KEY_RIGHT) // Right arrow or 'F'
    {
        if (app.player !is null)
        {
            app.player.fastForward(5.0);
        }
    }
}

void main(string[] args)
{
    AppContext appContext;
    string filename = (args.length > 1) ? args[1] : "samplevideo.mp4";

    if (!appContext.init("sdlffcd - Video Player", 800, 600))
    {
        return;
    }
    scope(exit) appContext.close();

    sdlffcd_app_set_key_callback(appContext.app, &handleKeyPress, &appContext);

    if (!appContext.player.open(filename))
    {
        stderr.writeln("Failed to open video file: ", filename);
        return;
    }

    writeln("\nStarting main event loop...");
    writeln("Controls: [Space/P] Pause/Resume, [R/Left] Rewind 5s, [F/Right] Fast Forward 5s, [Q/ESC] Quit\n");

    while (sdlffcd_app_is_running(appContext.app))
    {
        sdlffcd_app_poll_events(appContext.app);
        if (!sdlffcd_app_is_running(appContext.app)) break;

        bool active = appContext.player.update(appContext.app);
        if (!active && !appContext.player.isPaused())
        {
            writeln("Playback finished or stopped.");
            break;
        }

        Thread.sleep(dur!"msecs"(1));
    }

    writeln("Exited cleanly.");
}
