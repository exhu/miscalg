module sdlffcd.app;

import std.logger;
import std.stdio;

import sdlffcd.sdlffcd_clib;
import sdlffcd.sdl_logger;
import sdlffcd.app_context;
import sdlffcd.player_controller;

extern (C) struct AppEventCbUserData
{
  AppContext* appContext;
  PlayerController* playerController;
}

extern (C) void handleKeyPress(void* userDataPtr, uint key, ushort mod)
{
  AppEventCbUserData* userData = cast(AppEventCbUserData*) userDataPtr;
  AppContext* app = userData.appContext;
  userData.playerController.handleKeyPress(*app, key, mod);
}

extern (C) void handleWindowEvent(void* userDataPtr, sdlffcd_WindowEvent event)
{
  AppEventCbUserData* userData = cast(AppEventCbUserData*) userDataPtr;
  AppContext* app = userData.appContext;
  userData.playerController.handleWindowEvent(*app, event);
}

void printHelp()
{
  writeln("sdlffcd video trimming tool\n");
  writeln("Usage: sdlffcd [options] <video_file>\n");
  writeln("Options:");
  writeln("  --help, -h    Show this help message");
  writeln("  --quit        Quit application when reaching the end of video\n");
  writeln("Controls:");
  writeln("  Space         Pause / Resume video playback");
  writeln("  Left / Right  Seek backward / forward by 5 seconds");
  writeln("  [ / ]         Step 1 frame backward / forward (pauses if playing)");
  writeln("  B             Seek to video start frame (00:00:00, ignores IN-marker)");
  writeln("  E             Seek to video end frame (ignores OUT-marker)");
  writeln("  I             Set IN-marker (start of cut) to current frame time");
  writeln("  O             Set OUT-marker (last frame of cut) to current frame time");
  writeln("  Shift + I     Seek to IN-marker position (pauses if playing)");
  writeln("  Shift + O     Seek to OUT-marker position (pauses if playing)");
  writeln("  L             Toggle looping between IN and OUT markers");
  writeln("  M             Toggle audio mute / unmute");
  writeln("  F             Toggle fullscreen window mode");
  writeln("  V             Cycle current time overlay position (Top-Left -> Top-Right -> Bottom-Right -> Bottom-Left -> Hidden)");
  writeln("  Enter         Print lossless FFmpeg cut command to stdout");
  writeln("  Q / Esc       Quit application (auto-prints FFmpeg command if markers modified)");
}

int main(string[] args)
{
  sharedLog = cast(shared) new SdlLogger(LogLevel.info);

  if (args.length <= 1)
  {
    printHelp();
    return 0;
  }

  string filename = null;
  bool quitOnEnd = false;

  for (size_t i = 1; i < args.length; i++)
  {
    string arg = args[i];
    if (arg == "--help" || arg == "-h")
    {
      printHelp();
      return 0;
    }
    else if (arg == "--quit")
    {
      quitOnEnd = true;
    }
    else if (arg.length > 0 && arg[0] == '-')
    {
      errorf("Unknown option: %s", arg);
      printHelp();
      return 1;
    }
    else
    {
      filename = arg;
    }
  }

  if (filename is null)
  {
    printHelp();
    return 0;
  }

  AppContext appContext;

  if (!appContext.initialize("sdlffcd video trimming tool", 800, 600))
  {
    return 1;
  }
  scope (exit)
    appContext.destroy();

  PlayerController playerController;
  if (!playerController.initialize(appContext, filename, quitOnEnd))
  {
    error("Failed to initialize player controller resources.");
    return 1;
  }
  scope (exit)
    playerController.destroy();

  AppEventCbUserData userData;
  userData.appContext = &appContext;
  userData.playerController = &playerController;

  sdlffcd_app_set_key_callback(appContext.app, &handleKeyPress, &userData);
  sdlffcd_app_set_window_event_callback(appContext.app, &handleWindowEvent, &userData);

  if (!appContext.player.open(filename))
  {
    errorf("Failed to open video file: %s", filename);
    return 1;
  }

  info("Starting main event loop...");

  while (sdlffcd_app_is_running(appContext.app))
  {
    PlayerController.UpdateResult result = playerController.update(appContext);
    if (result.status == PlayerController.UpdateResult.Status.quit)
      break;

    sdlffcd_app_wait_events(appContext.app, result.nextUpdateMs);
  }

  info("Exited cleanly.");
  return 0;
}
