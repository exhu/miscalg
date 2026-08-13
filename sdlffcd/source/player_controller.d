module sdlffcd.player_controller;

import std.format;
import std.stdio;

import sdlffcd.player_view;
import sdlffcd.models;
import sdlffcd.observable;
import sdlffcd.app_context;
import sdlffcd.sdlffcd_clib;

struct Hms1000
{
  long hours, minutes, seconds;
  int mSeconds;

  void fromSeconds(double dsec)
  {
    long sec = cast(long) dsec;
    mSeconds = cast(int)((dsec - sec) * 1000.0);
    if (mSeconds < 0)
      mSeconds = 0;
    if (mSeconds > 999)
      mSeconds = 999;
    hours = sec / 3600;
    minutes = (sec % 3600) / 60;
    seconds = sec % 60;
  }
}

struct PlayerController
{
  View view;
  Tracked!ViewModel viewModel;
  Tracked!PlayerModel playerModel;
  Tracked!EditModel editModel;

  void handleKeyPress(ref AppContext app, uint key)
  {
    // TODO update playerModel to be in sync with appContext.player state
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

    if (state.frameRendered)
    {
      appContext.renderTimestamp();
    }

    bool dirty = false;
    if (playerModel.consumesUpdate())
    {
      dirty = true;
      viewModel.formattedCurrentTotalTime = formatTimestamp(playerModel.timePosition, playerModel
          .timeDuration);
    }
    if (editModel.consumesUpdate())
    {
      dirty = true;
      // TODO future edit features placeholder
    }
    if (dirty)
      view.update(viewModel);

    return UpdateResult(UpdateResult.Status.callAgain, state.nextUpdateMs);
  }

  void cycleTimePosition()
  {
    if (playerModel.timePosition == TimePosition.max)
      playerModel.timePosition = TimePosition.min;
    else
      playerModel.timePosition = playerModel.timePosition+1;
  }

private:
  string formatTimestamp(double posSec, double totalSec)
  {
    if (posSec < 0.0)
      posSec = 0.0;
    if (totalSec < 0.0)
      totalSec = 0.0;

    long pSec = cast(long) posSec;
    Hms1000 current, total;
    current.fromSeconds(posSec);
    total.fromSeconds(totalSec);

    return format("%02d:%02d:%02d.%03d / %02d:%02d:%02d.%03d",
      current.hours, current.minutes, current.seconds, current.mSeconds,
      total.hours, total.minutes, total.seconds, total.mSeconds);
  }

}
