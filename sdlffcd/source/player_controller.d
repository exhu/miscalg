module sdlffcd.ui_view_model;

import std.format;
import sdlffcd.player_view;
import sdlffcd.models;

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

struct Controller
{
  View view;
  Tracked!ViewModel viewModel;
  Tracked!PlayerModel playerModel;
  Tracked!EditModel editModel;

  void update()
  {
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
      // TODO
    }
    if (dirty)
      view.update(viewModel);
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
