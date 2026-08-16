module sdlffcd.player_view;

import std.logger : error, errorf;
import std.string;
import std.math : floor;
import sdlffcd.sdlffcd_clib;
import sdlffcd.models;

struct View
{
  sdlffcd_Font* timestampFont;
  sdlffcd_Text* timestampText;
  sdlffcd_Text* inOutText;
  int lastDpi = 0;
  string lastCurrentTotalTime;
  string lastInOutTime;
  int tsW = 0, tsH = 0;
  int ioW = 0, ioH = 0;

  void updateDisplayScale(sdlffcd_AppContext* app)
  {
    if (app is null || timestampFont is null)
      return;
    float displayScale = sdlffcd_app_get_display_scale(app);
    if (displayScale < 1.0f)
      displayScale = 1.0f;
    int dpi = cast(int)(96.0f * displayScale + 0.5f);
    if (dpi == lastDpi)
      return;
    lastDpi = dpi;
    sdlffcd_font_set_size_dpi(timestampFont, 19.0f, dpi, dpi);
    lastCurrentTotalTime = null;
    lastInOutTime = null;
  }

  bool initialize(sdlffcd_AppContext* app)
  {
    string fontPath = "fonts/GoogleSansCode-Regular.ttf";
    timestampFont = sdlffcd_font_open(toStringz(fontPath), 19.0f);
    if (timestampFont !is null)
    {
      sdlffcd_font_set_hinting(timestampFont, sdlffcd_FontHinting.SDLFFCD_FONT_HINTING_NORMAL);
      updateDisplayScale(app);
      timestampText = sdlffcd_text_create(app, timestampFont, "00:00:00.000 / 00:00:00.000");
      inOutText = sdlffcd_text_create(app, timestampFont, "IN: 00:00:00.000  OUT: 00:00:00.000");

      if (timestampText !is null)
      {
        sdlffcd_text_set_color(timestampText, 255, 255, 255, 255);
      }
      else
      {
        error("Failed to create timestamp text object.");
      }

      if (inOutText !is null)
      {
        sdlffcd_text_set_color(inOutText, 255, 255, 255, 255);
      }
      else
      {
        error("Failed to create in-out text object.");
      }
    }
    else
    {
      errorf("Failed to open font %s", fontPath);
    }
    return timestampFont !is null && timestampText !is null && inOutText !is null;
  }

  void destroy()
  {
    if (inOutText !is null)
    {
      sdlffcd_text_destroy(inOutText);
      inOutText = null;
    }

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

    lastDpi = 0;
    lastCurrentTotalTime = null;
    lastInOutTime = null;
    tsW = 0;
    tsH = 0;
    ioW = 0;
    ioH = 0;
  }

  void renderTimeStamp(sdlffcd_AppContext* app, ref const(ViewModel) viewModel)
  {
    if (app is null || timestampText is null)
      return;

    if (viewModel.timePosition == TimePosition.invisible)
    {
      return;
    }

    if (viewModel.formattedCurrentTotalTime.length > 0 && viewModel.formattedCurrentTotalTime != lastCurrentTotalTime)
    {
      lastCurrentTotalTime = viewModel.formattedCurrentTotalTime;
      sdlffcd_text_set_string(timestampText, toStringz(lastCurrentTotalTime));
      sdlffcd_text_get_size(timestampText, &tsW, &tsH);
    }

    if (inOutText !is null && viewModel.formattedInOutTime.length > 0 && viewModel.formattedInOutTime != lastInOutTime)
    {
      lastInOutTime = viewModel.formattedInOutTime;
      sdlffcd_text_set_string(inOutText, toStringz(lastInOutTime));
      sdlffcd_text_get_size(inOutText, &ioW, &ioH);
    }

    float margin = 10.0f;
    float gap = 10.0f;
    float windowW = cast(float) viewModel.windowWidth;
    float windowH = cast(float) viewModel.windowHeight;

    float tsX = margin;
    float tsY = margin;
    float ioX = margin;
    float ioY = margin + tsH + gap;

    final switch (viewModel.timePosition)
    {
    case TimePosition.topLeft:
      tsX = margin;
      tsY = margin;
      ioX = margin;
      ioY = tsY + tsH + gap;
      break;
    case TimePosition.topRight:
      tsX = windowW - tsW - margin;
      tsY = margin;
      ioX = windowW - ioW - margin;
      ioY = tsY + tsH + gap;
      break;
    case TimePosition.bottomRight:
      ioX = windowW - ioW - margin;
      ioY = windowH - ioH - margin;
      tsX = windowW - tsW - margin;
      tsY = ioY - tsH - gap;
      break;
    case TimePosition.bottomLeft:
      ioX = margin;
      ioY = windowH - ioH - margin;
      tsX = margin;
      tsY = ioY - tsH - gap;
      break;
    case TimePosition.invisible:
      return;
    }

    tsX = floor(tsX);
    tsY = floor(tsY);
    ioX = floor(ioX);
    ioY = floor(ioY);

    sdlffcd_text_draw_with_bg(app, timestampText, tsX, tsY, 0, 0, 0, 255, 4.0f);
    if (inOutText !is null && viewModel.formattedInOutTime.length > 0)
    {
      sdlffcd_text_draw_with_bg(app, inOutText, ioX, ioY, 0, 0, 0, 255, 4.0f);
    }
  }

  void render(sdlffcd_AppContext* app, ref const(ViewModel) viewModel)
  {
    renderTimeStamp(app, viewModel);
    sdlffcd_app_present(app);
  }
}
