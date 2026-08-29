module sdlffcd.app_context;

import std.logger : info, error;
import std.string;
import sdlffcd.sdlffcd_clib;
import sdlffcd.video_player;

struct AppContext
{
    sdlffcd_AppContext* app;
    VideoPlayer player;

    bool initialize(string title = "sdlffcd video trimming tool", int width = 800, int height = 600)
    {
        info("Initializing SDL application...");
        app = sdlffcd_app_init(toStringz(title), width, height);
        if (app is null)
        {
            error("Failed to initialize application context.");
            return false;
        }

        player = new VideoPlayer();
        return true;
    }

    void destroy()
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

