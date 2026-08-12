module app_context;

import std.stdio;
import std.string;
import std.format;
import sdlffcd_clib;
import video_player;

struct AppContext
{
    sdlffcd_AppContext* app;
    VideoPlayer player;

    sdlffcd_Font* timestampFont;
    sdlffcd_Text* timestampText;

    bool initialize(string title = "sdlffcd - Video Player", int width = 800, int height = 600)
    {
        writeln("Initializing SDL application...");
        app = sdlffcd_app_init(toStringz(title), width, height);
        if (app is null)
        {
            stderr.writeln("Failed to initialize application context.");
            return false;
        }

        player = new VideoPlayer();

        // Load 19pt GoogleSansCode-Regular.ttf font and create timestamp text object
        string fontPath = "fonts/GoogleSansCode-Regular.ttf";
        timestampFont = sdlffcd_font_open(toStringz(fontPath), 19.0f);
        if (timestampFont !is null)
        {
            timestampText = sdlffcd_text_create(app, timestampFont, "00:00:00.000 / 00:00:00.000");
            if (timestampText !is null)
            {
                sdlffcd_text_set_color(timestampText, 255, 255, 255, 255);
            }
            else
            {
                stderr.writeln("Failed to create timestamp text object.");
            }
        }
        else
        {
            stderr.writefln("Failed to open font %s", fontPath);
        }

        return true;
    }

    void renderTimestamp()
    {
        if (app is null || player is null) return;

        if (timestampText !is null)
        {
            double currentPts = player.getCurrentPts();
            double lastFrameTime = player.getDuration();
            string timeStr = formatTimestamp(currentPts, lastFrameTime);
            sdlffcd_text_set_string(timestampText, toStringz(timeStr));
            sdlffcd_text_draw_with_bg(app, timestampText, 10.0f, 10.0f, 0, 0, 0, 255, 4.0f);
        }
        sdlffcd_app_present(app);
    }

    void destroy()
    {
        if (timestampText !is null)
        {
            sdlffcd_text_destroy(timestampText);
            timestampText = null;
        }

        if (timestampFont !is null)
        {
            sdlffcd_font_close(timestampFont);
            timestampFont = null;
        }

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

string formatTimestamp(double posSec, double totalSec)
{
    if (posSec < 0.0) posSec = 0.0;
    if (totalSec < 0.0) totalSec = 0.0;

    long pSec = cast(long)posSec;
    int pMsec = cast(int)((posSec - pSec) * 1000.0);
    if (pMsec < 0) pMsec = 0; if (pMsec > 999) pMsec = 999;
    long pHours = pSec / 3600;
    long pMins = (pSec % 3600) / 60;
    long pSecs = pSec % 60;

    long tSec = cast(long)totalSec;
    int tMsec = cast(int)((totalSec - tSec) * 1000.0);
    if (tMsec < 0) tMsec = 0; if (tMsec > 999) tMsec = 999;
    long tHours = tSec / 3600;
    long tMins = (tSec % 3600) / 60;
    long tSecs = tSec % 60;

    return format("%02d:%02d:%02d.%03d / %02d:%02d:%02d.%03d",
        pHours, pMins, pSecs, pMsec,
        tHours, tMins, tSecs, tMsec);
}

unittest
{
    string ts1 = formatTimestamp(12.3456, 125.789);
    assert(ts1 == "00:00:12.345 / 00:02:05.789");

    string ts2 = formatTimestamp(3661.050, 7200.0);
    assert(ts2 == "01:01:01.050 / 02:00:00.000");

    string ts3 = formatTimestamp(0.0, 0.0);
    assert(ts3 == "00:00:00.000 / 00:00:00.000");
}
