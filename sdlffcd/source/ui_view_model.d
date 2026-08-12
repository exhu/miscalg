module sdlffcd.ui_view_model;

import std.format;

enum TimePosition
{
  topLeft,
  topRight,
  bottomRight,
  bottomLeft,
  invisible,
}

struct Hms1000
{
  long hours,minutes,seconds;
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

/** This depends on Model, and also controls display mode, e.g. timestamp position which is
    cycled by key press.
*/
struct ViewModel
{
  string formattedCurrentTotalTime;
  TimePosition timePosition;

  void updateFromModel(in Model m)
  {
    formattedCurrentTotalTime = formatTimestamp(m.timePosition, m.timeDuration);
  }

  void cycleTimePosition()
  {
    if (timePosition == TimePosition.max)
      timePosition = TimePosition.min;
    else
      timePosition += 1;
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

/** Some values that a retrieved/changed in VideoPlayer and other lower components
   are replicated in the Model as a logic update step. So the model depends
   on the state of the program.
 */
struct Model
{
  bool isPaused;
  bool isLooping;
  double timePosition;
  double timeDuration;
  /// In cut point (always less than timeDuration)
  double timeIn;
  /// Out cut point (the time of the beginning of the frame), always less than timeDuration
  double timeOut;
}
