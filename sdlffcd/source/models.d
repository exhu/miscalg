module sdlffcd.models;

import std.format;
import sdlffcd.observable;

enum TimePosition
{
  topLeft,
  topRight,
  bottomRight,
  bottomLeft,
  invisible,
}

/** This depends on Model, and also controls display mode, e.g. timestamp position which is
    cycled by key press.
*/
struct ViewFields
{
  string formattedCurrentTotalTime;
  TimePosition timePosition;
}

alias ViewModel = ObservableModel!ViewFields;

/** Some values that a retrieved/changed in VideoPlayer and other lower components
   are replicated in the Model as a logic update step. So the model depends
   on the state of the program.
 */
struct PlayerFields
{
  bool isPaused;
  bool isLooping;
  double timePosition;
  double timeDuration;
}

alias PlayerModel = ObservableModel!PlayerFields;

struct EditFields
{
  /// In cut point (always less than timeDuration)
  double timeIn;
  /// Out cut point (the time of the beginning of the frame), always less than timeDuration
  double timeOut;
}

alias EditModel = ObservableModel!EditFields;

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

string formatTimestamp(double posSec, double totalSec)
{
  if (posSec < 0.0)
    posSec = 0.0;
  if (totalSec < 0.0)
    totalSec = 0.0;

  Hms1000 current, total;
  current.fromSeconds(posSec);
  total.fromSeconds(totalSec);

  return format("%02d:%02d:%02d.%03d / %02d:%02d:%02d.%03d",
    current.hours, current.minutes, current.seconds, current.mSeconds,
    total.hours, total.minutes, total.seconds, total.mSeconds);
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

