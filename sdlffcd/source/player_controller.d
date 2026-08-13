module sdlffcd.player_controller;

import std.format;
import std.stdio;

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

  bool initialize(ref AppContext appContext)
  {
    return view.initialize(appContext.app);
  }

  void destroy()
  {
    view.destroy();
  }

  void handleKeyPress(ref AppContext app, uint key)
  {
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
    else if (key == sdlffcd_Key.SDLFFCD_KEY_T)
    {
        cycleTimePosition();
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
    auto state = appContext.player.update(appContext.app);
    if (state.isVideoEnd)
    {
      writeln("Playback finished (end of video stream).");
      return UpdateResult(UpdateResult.Status.quit);
    }
    if (state.isError)
    {
      stderr.writeln("Playback stopped due to error.");
      return UpdateResult(UpdateResult.Status.quit);
    }

    if (appContext.player !is null)
    {
      playerModel.timePosition = appContext.player.getCurrentPts();
      playerModel.timeDuration = appContext.player.getDuration();
    }

    bool dirty = false;
    if (playerModel.consumesUpdate())
    {
      dirty = true;
      viewModel.formattedCurrentTotalTime = formatTimestamp(playerModel.timePosition, playerModel.timeDuration);
    }
    if (editModel.consumesUpdate())
    {
      dirty = true;
      // future edit features placeholder
    }

    if (state.frameRendered || dirty)
    {
      view.render(appContext.app, viewModel);
    }

    if (!sdlffcd_app_is_running(appContext.app))
      return UpdateResult(UpdateResult.Status.quit);

    return UpdateResult(UpdateResult.Status.callAgain, state.nextUpdateMs);
  }

  void cycleTimePosition()
  {
    auto nextPos = cast(TimePosition)((cast(int) viewModel.timePosition + 1) % (cast(int) TimePosition.invisible + 1));
    viewModel.timePosition = nextPos;
  }
}

