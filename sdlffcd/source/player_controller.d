module sdlffcd.player_controller;

import std.format;
import std.logger : info, infof, error;
import std.stdio : writeln;

import sdlffcd.player_view;
import sdlffcd.models;
import sdlffcd.observable;
import sdlffcd.app_context;
import sdlffcd.sdlffcd_clib;

struct PlayerController
{
  View view;
  Tracked!ViewModel viewModel;
  Tracked!PlayerModel playerModel;
  Tracked!EditModel editModel;
  string videoFilename;
  bool quitOnEnd = false;
  bool markersInitialized = false;

  bool initialize(ref AppContext appContext, string filename = "samplevideo.mp4", bool quitOnEnd = false)
  {
    this.videoFilename = filename;
    this.quitOnEnd = quitOnEnd;
    updateWindowSize(appContext);
    return view.initialize(appContext.app);
  }

  void destroy()
  {
    view.destroy();
  }

  void updateWindowSize(ref AppContext appContext)
  {
    if (appContext.app !is null)
    {
      int w = 0, h = 0;
      if (sdlffcd_app_get_window_size(appContext.app, &w, &h) && w > 0 && h > 0)
      {
        viewModel.windowWidth = w;
        viewModel.windowHeight = h;
      }
      view.updateDisplayScale(appContext.app);
    }
  }

  void printFfmpegCutCommand(ref AppContext app)
  {
    double fps = (app.player !is null) ? app.player.getFps() : 0.0;
    string cmd = generateFfmpegCutCommand(videoFilename, editModel.timeIn, editModel.timeOut, fps);
    writeln("\nFFmpeg cut command:");
    writeln(cmd);
    writeln();
  }

  void handleKeyPress(ref AppContext app, uint key, ushort mod = 0)
  {
    bool isShift = (mod & sdlffcd_KeyMod.SDLFFCD_KMOD_SHIFT) != 0;

    if (key == sdlffcd_Key.SDLFFCD_KEY_ESCAPE ||
        key == sdlffcd_Key.SDLFFCD_KEY_Q)
    {
        if (editModel.markersModified)
        {
            printFfmpegCutCommand(app);
        }
        info("Key press received in D (Q / ESCAPE). Requesting app stop...");
        if (app.app !is null)
        {
            sdlffcd_app_stop(app.app);
        }
    }
    else if (key == sdlffcd_Key.SDLFFCD_KEY_SPACE)
    {
        if (app.player !is null)
        {
            app.player.togglePause();
        }
    }
    else if (key == sdlffcd_Key.SDLFFCD_KEY_LEFT)
    {
        if (app.player !is null)
        {
            app.player.rewind(5.0);
        }
    }
    else if (key == sdlffcd_Key.SDLFFCD_KEY_RIGHT)
    {
        if (app.player !is null)
        {
            app.player.fastForward(5.0);
        }
    }
    else if (key == sdlffcd_Key.SDLFFCD_KEY_LEFTBRACKET)
    {
        if (app.player !is null)
        {
            app.player.stepFrame(-1);
        }
    }
    else if (key == sdlffcd_Key.SDLFFCD_KEY_RIGHTBRACKET)
    {
        if (app.player !is null)
        {
            app.player.stepFrame(1);
        }
    }
    else if (key == sdlffcd_Key.SDLFFCD_KEY_B)
    {
        if (app.player !is null)
        {
            app.player.seekTo(0.0);
        }
    }
    else if (key == sdlffcd_Key.SDLFFCD_KEY_E)
    {
        if (app.player !is null)
        {
            app.player.seekTo(app.player.getEndFrameTime());
        }
    }
    else if (key == sdlffcd_Key.SDLFFCD_KEY_I)
    {
        if (isShift)
        {
            if (app.player !is null)
            {
                if (!app.player.isPaused)
                {
                    app.player.pause();
                }
                app.player.seekTo(editModel.timeIn);
            }
        }
        else
        {
            if (app.player !is null)
            {
                double cur = app.player.getCurrentPts();
                setInMarker(cur);
                infof("IN-marker set to %.3f s (OUT: %.3f s)", editModel.timeIn, editModel.timeOut);
            }
        }
    }
    else if (key == sdlffcd_Key.SDLFFCD_KEY_O)
    {
        if (isShift)
        {
            if (app.player !is null)
            {
                if (!app.player.isPaused)
                {
                    app.player.pause();
                }
                app.player.seekTo(editModel.timeOut);
            }
        }
        else
        {
            if (app.player !is null)
            {
                double cur = app.player.getCurrentPts();
                setOutMarker(cur);
                infof("OUT-marker set to %.3f s (IN: %.3f s)", editModel.timeOut, editModel.timeIn);
            }
        }
    }
    else if (key == sdlffcd_Key.SDLFFCD_KEY_L)
    {
        playerModel.isLooping = !playerModel.isLooping;
        infof("Loop mode: %s", playerModel.isLooping ? "ON" : "OFF");
    }
    else if (key == sdlffcd_Key.SDLFFCD_KEY_M)
    {
        if (app.player !is null)
        {
            app.player.toggleMute();
        }
    }
    else if (key == sdlffcd_Key.SDLFFCD_KEY_F)
    {
        if (app.app !is null)
        {
            sdlffcd_app_toggle_fullscreen(app.app);
        }
    }
    else if (key == sdlffcd_Key.SDLFFCD_KEY_V)
    {
        cycleTimePosition();
    }
    else if (key == sdlffcd_Key.SDLFFCD_KEY_RETURN)
    {
        printFfmpegCutCommand(app);
    }
  }

  struct UpdateResult
  {
  enum Status
    {
      quit,
      callAgain,
    }
    Status status;
    int nextUpdateMs;
  }

  UpdateResult update(ref AppContext appContext)
  {
    updateWindowSize(appContext);

    if (appContext.player !is null && appContext.player.isLoaded && !markersInitialized)
    {
      editModel.timeIn = 0.0;
      editModel.timeOut = appContext.player.getEndFrameTime();
      editModel.markersModified = false;
      markersInitialized = true;
    }

    auto state = appContext.player.update(appContext.app);
    if (state.isVideoEnd)
    {
      if (playerModel.isLooping)
      {
        appContext.player.seekTo(editModel.timeIn);
      }
      else if (quitOnEnd)
      {
        info("Playback finished (end of video stream). Quitting...");
        return UpdateResult(UpdateResult.Status.quit);
      }
      else
      {
        if (!appContext.player.isPaused)
        {
          appContext.player.pause();
        }
      }
    }
    if (state.isError)
    {
      error("Playback stopped due to error.");
      return UpdateResult(UpdateResult.Status.quit);
    }

    if (appContext.player !is null)
    {
      playerModel.timePosition = appContext.player.getCurrentPts();
      playerModel.timeDuration = appContext.player.getDuration();
      playerModel.isPaused = appContext.player.isPaused;
      playerModel.isMuted = appContext.player.isMuted;
      playerModel.isEnd = appContext.player.isAtEnd;
      playerModel.currentFrame = appContext.player.getCurrentFrame();
      playerModel.totalFrames = appContext.player.getTotalFrames();

      // Check looping boundary during normal playback
      if (playerModel.isLooping && !playerModel.isPaused)
      {
        if (playerModel.timePosition >= editModel.timeOut && editModel.timeOut > editModel.timeIn)
        {
          appContext.player.seekTo(editModel.timeIn);
          playerModel.timePosition = editModel.timeIn;
        }
      }
    }

    bool dirty = false;
    if (playerModel.pollUpdate() || editModel.pollUpdate())
    {
      dirty = true;
      viewModel.formattedCurrentTotalTime = formatTimestamp(
        playerModel.timePosition,
        playerModel.timeDuration,
        playerModel.currentFrame,
        playerModel.totalFrames,
        playerModel.isLooping,
        playerModel.isPaused,
        playerModel.isMuted,
        playerModel.isEnd);
      viewModel.formattedInOutTime = formatInOut(editModel.timeIn, editModel.timeOut);
    }
    if (viewModel.pollUpdate())
    {
      dirty = true;
    }

    if (state.frameRendered)
    {
      view.render(appContext.app, viewModel);
    }
    else if (dirty)
    {
      if (appContext.player !is null)
      {
        appContext.player.redraw(appContext.app);
      }
      view.render(appContext.app, viewModel);
    }

    if (!sdlffcd_app_is_running(appContext.app))
      return UpdateResult(UpdateResult.Status.quit);

    return UpdateResult(UpdateResult.Status.callAgain, state.nextUpdateMs);
  }

  void setInMarker(double pos)
  {
    if (pos < 0.0)
      pos = 0.0;
    if (pos > editModel.timeOut)
    {
      double prevOut = editModel.timeOut;
      editModel.timeIn = prevOut;
      editModel.timeOut = pos;
    }
    else
    {
      editModel.timeIn = pos;
    }
    editModel.markersModified = true;
  }

  void setOutMarker(double pos)
  {
    if (pos < 0.0)
      pos = 0.0;
    if (pos < editModel.timeIn)
    {
      double prevIn = editModel.timeIn;
      editModel.timeOut = prevIn;
      editModel.timeIn = pos;
    }
    else
    {
      editModel.timeOut = pos;
    }
    editModel.markersModified = true;
  }

  void cycleTimePosition()
  {
    auto nextPos = cast(TimePosition)((cast(int) viewModel.timePosition + 1) % (cast(int) TimePosition.invisible + 1));
    viewModel.timePosition = nextPos;
  }
}

unittest
{
  PlayerController controller;
  assert(controller.viewModel.windowWidth == defaultWindowWidth);
  assert(controller.viewModel.windowHeight == defaultWindowHeight);
  assert(controller.viewModel.pollUpdate());
  assert(!controller.viewModel.pollUpdate());

  controller.viewModel.windowWidth = 1280;
  controller.viewModel.windowHeight = 720;

  assert(controller.viewModel.pollUpdate());
  assert(controller.viewModel.windowWidth == 1280);
  assert(controller.viewModel.windowHeight == 720);
  assert(!controller.viewModel.pollUpdate());

  assert(!controller.playerModel.isLooping);
  controller.playerModel.isLooping = true;
  assert(controller.playerModel.pollUpdate());
  assert(controller.playerModel.isLooping);

  controller.editModel.timeIn = 5.0;
  controller.editModel.timeOut = 15.0;
  controller.editModel.markersModified = true;
  assert(controller.editModel.pollUpdate());
  assert(controller.editModel.markersModified);

  // Test setInMarker and setOutMarker swapping
  controller.editModel.timeIn = 5.0;
  controller.editModel.timeOut = 20.0;

  // Normal setInMarker: 2.0 < 20.0
  controller.setInMarker(2.0);
  assert(controller.editModel.timeIn == 2.0);
  assert(controller.editModel.timeOut == 20.0);

  // Swapped setInMarker: 25.0 > 20.0 -> IN becomes old OUT (20.0), OUT becomes 25.0
  controller.setInMarker(25.0);
  assert(controller.editModel.timeIn == 20.0);
  assert(controller.editModel.timeOut == 25.0);

  // Normal setOutMarker: 30.0 > 20.0
  controller.setOutMarker(30.0);
  assert(controller.editModel.timeIn == 20.0);
  assert(controller.editModel.timeOut == 30.0);

  // Swapped setOutMarker: 10.0 < 20.0 -> OUT becomes old IN (20.0), IN becomes 10.0
  controller.setOutMarker(10.0);
  assert(controller.editModel.timeIn == 10.0);
  assert(controller.editModel.timeOut == 20.0);

  controller.viewModel.timePosition = TimePosition.topLeft;
  controller.cycleTimePosition();
  assert(controller.viewModel.timePosition == TimePosition.topRight);
  controller.cycleTimePosition();
  assert(controller.viewModel.timePosition == TimePosition.bottomRight);
  controller.cycleTimePosition();
  assert(controller.viewModel.timePosition == TimePosition.bottomLeft);
  controller.cycleTimePosition();
  assert(controller.viewModel.timePosition == TimePosition.invisible);
  controller.cycleTimePosition();
  assert(controller.viewModel.timePosition == TimePosition.topLeft);
}

