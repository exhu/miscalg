module app_context;

import std.stdio;
import std.string;
import sdlffcd_clib;
import video_player;

struct AppContext
{
    sdlffcd_AppContext* app;
    VideoPlayer player;

    bool init(string title = "sdlffcd - Video Player", int width = 800, int height = 600)
    {
        writeln("Initializing SDL application...");
        app = sdlffcd_app_init(toStringz(title), width, height);
        if (app is null)
        {
            stderr.writeln("Failed to initialize application context.");
            return false;
        }

        player = new VideoPlayer();
        return true;
    }

    void close()
    {
        if (player !is null)
        {
            player.close();
            player = null;
        }

        if (app !is null)
        {
            sdlffcd_app_shutdown(app);
            app = null;
        }
    }
}

