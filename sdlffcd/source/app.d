import std.stdio;
import std.string;
import core.thread;
import std.datetime;

import sdlffcd_clib;
import frame_ring_buffer;
import video_player;

__gshared VideoPlayer g_player = null;

extern(C) void handleKeyPress(void* userdata, uint key)
{
    sdlffcd_AppContext* app = cast(sdlffcd_AppContext*)userdata;
    if (key == sdlffcd_Key.SDLFFCD_KEY_ESCAPE || key == sdlffcd_Key.SDLFFCD_KEY_Q || key == 'Q')
    {
        writeln("Key press received in D (Q / ESCAPE). Requesting app stop...");
        if (app !is null)
        {
            sdlffcd_app_stop(app);
        }
    }
    else if (key == ' ' || key == 'p' || key == 'P')
    {
        if (g_player !is null)
        {
            g_player.togglePause();
        }
    }
    else if (key == 'r' || key == 'R' || key == 1073741904) // Left arrow or 'R'
    {
        if (g_player !is null)
        {
            g_player.rewind(5.0);
        }
    }
    else if (key == 'f' || key == 'F' || key == 1073741903) // Right arrow or 'F'
    {
        if (g_player !is null)
        {
            g_player.fastForward(5.0);
        }
    }
}

void main(string[] args)
{
    string filename = (args.length > 1) ? args[1] : "samplevideo.mp4";

    writeln("Initializing SDL application...");
    sdlffcd_AppContext* app = sdlffcd_app_init("sdlffcd - Video Player", 800, 600);
    if (app is null)
    {
        stderr.writeln("Failed to initialize application context.");
        return;
    }
    scope(exit) sdlffcd_app_shutdown(app);

    sdlffcd_app_set_key_callback(app, &handleKeyPress, app);

    VideoPlayer player = new VideoPlayer();
    g_player = player;
    scope(exit)
    {
        player.close();
        g_player = null;
    }

    if (!player.open(filename))
    {
        stderr.writeln("Failed to open video file: ", filename);
        return;
    }

    writeln("\nStarting main event loop...");
    writeln("Controls: [Space/P] Pause/Resume, [R/Left] Rewind 5s, [F/Right] Fast Forward 5s, [Q/ESC] Quit\n");

    while (sdlffcd_app_is_running(app))
    {
        sdlffcd_app_poll_events(app);
        if (!sdlffcd_app_is_running(app)) break;

        bool active = player.update(app);
        if (!active && !player.isPaused())
        {
            writeln("Playback finished or stopped.");
            break;
        }

        Thread.sleep(dur!"msecs"(1));
    }

    writeln("Exited cleanly.");
}
