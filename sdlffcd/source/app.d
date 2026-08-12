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

    if (!appContext.initialize("sdlffcd - Video Player", 800, 600))
    {
        return;
    }
    scope(exit) appContext.destroy();

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
        auto state = appContext.player.update(appContext.app);
        if (state.isVideoEnd)
        {
            writeln("Playback finished (end of video stream).");
            break;
        }
        if (state.isError)
        {
            stderr.writeln("Playback stopped due to error.");
            break;
        }

        if (state.frameRendered)
        {
            appContext.renderTimestamp();
        }

        if (!sdlffcd_app_is_running(appContext.app)) break;

        sdlffcd_app_wait_events(appContext.app, state.nextUpdateMs);
    }

    writeln("Exited cleanly.");
}
