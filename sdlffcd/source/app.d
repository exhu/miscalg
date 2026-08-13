module sdlffcd.app;

import std.stdio;
import std.string;
import std.datetime;

import sdlffcd.sdlffcd_clib;
import sdlffcd.app_context;
import sdlffcd.player_controller;

extern (C) struct KeyPressCbUserData
{
  AppContext* appContext;
  PlayerController* playerController;
}

extern (C) void handleKeyPress(void* userDataPtr, uint key)
{
  KeyPressCbUserData* userData = cast(KeyPressCbUserData*) userDataPtr;
  AppContext* app = userData.appContext;
  userData.playerController.handleKeyPress(*app, key);
}

void main(string[] args)
{
  AppContext appContext;
  string filename = (args.length > 1) ? args[1] : "samplevideo.mp4";

  if (!appContext.initialize("sdlffcd - Video Player", 800, 600))
  {
    return;
  }
  scope (exit)
    appContext.destroy();

  PlayerController playerController;

  KeyPressCbUserData userData;
  userData.appContext = &appContext;
  userData.playerController = &playerController;

  sdlffcd_app_set_key_callback(appContext.app, &handleKeyPress, &userData);

  if (!appContext.player.open(filename))
  {
    stderr.writeln("Failed to open video file: ", filename);
    return;
  }

  writeln("\nStarting main event loop...");
  writeln(
    "Controls: [Space/P] Pause/Resume, [R/Left] Rewind 5s, [F/Right] Fast Forward 5s, [Q/ESC] Quit\n");

  while (sdlffcd_app_is_running(appContext.app))
  {
    PlayerController.UpdateResult result = playerController.update(appContext);
    if (result.status == PlayerController.UpdateResult.Status.quit)
      break;

    if (!sdlffcd_app_is_running(appContext.app))
      break;

    sdlffcd_app_wait_events(appContext.app, result.nextUpdateMs);
  }

  writeln("Exited cleanly.");
}
