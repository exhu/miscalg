module sdlffcd.player_view;

import std.stdio;
import std.string;
import sdlffcd.sdlffcd_clib;
import sdlffcd.models;

struct View
{
  sdlffcd_Font* timestampFont;
  sdlffcd_Text* timestampText;

  bool initialize(sdlffcd_AppContext* app)
  {
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
    return timestampFont !is null && timestampText !is null;
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
  }

  void renderTimeStamp(sdlffcd_AppContext* app, ref const(ViewModel) viewModel)
  {
    if (app is null || timestampText is null)
      return;

    if (viewModel.timePosition == TimePosition.invisible)
    {
      return;
    }

    if (viewModel.formattedCurrentTotalTime.length > 0)
    {
      sdlffcd_text_set_string(timestampText, toStringz(viewModel.formattedCurrentTotalTime));
    }

    int textW = 0, textH = 0;
    sdlffcd_text_get_size(timestampText, &textW, &textH);

    float posX = 10.0f;
    float posY = 10.0f;
    float windowW = 800.0f;
    float windowH = 600.0f;

    final switch (viewModel.timePosition)
    {
    case TimePosition.topLeft:
      posX = 10.0f;
      posY = 10.0f;
      break;
    case TimePosition.topRight:
      posX = windowW - textW - 10.0f;
      posY = 10.0f;
      break;
    case TimePosition.bottomRight:
      posX = windowW - textW - 10.0f;
      posY = windowH - textH - 10.0f;
      break;
    case TimePosition.bottomLeft:
      posX = 10.0f;
      posY = windowH - textH - 10.0f;
      break;
    case TimePosition.invisible:
      return;
    }

    sdlffcd_text_draw_with_bg(app, timestampText, posX, posY, 0, 0, 0, 255, 4.0f);
  }

  void render(sdlffcd_AppContext* app, ref const(ViewModel) viewModel)
  {
    renderTimeStamp(app, viewModel);
    sdlffcd_app_present(app);
  }
}
