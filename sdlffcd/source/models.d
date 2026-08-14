module sdlffcd.models;

import std.format;
import std.path : stripExtension, extension;
import sdlffcd.observable;

enum TimePosition
{
  topLeft,
  topRight,
  bottomRight,
  bottomLeft,
  invisible,
}

enum defaultWindowWidth = 800;
enum defaultWindowHeight = 600;

/** This depends on Model, and also controls display mode, e.g. timestamp position which is
    cycled by key press.
*/
struct ViewFields
{
  string formattedCurrentTotalTime;
  string formattedInOutTime;
  TimePosition timePosition;
  int windowWidth = defaultWindowWidth;
  int windowHeight = defaultWindowHeight;
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
  bool isMuted;
  double timePosition;
  double timeDuration;
}

alias PlayerModel = ObservableModel!PlayerFields;

struct EditFields
{
  /// In cut point (always less than or equal to timeDuration)
  double timeIn;
  /// Out cut point (the time of the beginning of the frame), always less than or equal to timeDuration
  double timeOut;
  /// Whether IN/OUT markers have been modified by user
  bool markersModified;
}

alias EditModel = ObservableModel!EditFields;

struct Hms1000
{
  long hours, minutes, seconds;
  int mSeconds;

  void fromSeconds(double dsec)
  {
    if (dsec < 0.0)
      dsec = 0.0;
    long totalMs = cast(long) (dsec * 1000.0 + 1e-6);
    mSeconds = cast(int)(totalMs % 1000);
    long sec = totalMs / 1000;
    hours = sec / 3600;
    minutes = (sec % 3600) / 60;
    seconds = sec % 60;
  }
}

string formatTimestamp(double posSec, double totalSec, bool isLooping = false, bool isPaused = false, bool isMuted = false)
{
  if (posSec < 0.0)
    posSec = 0.0;
  if (totalSec < 0.0)
    totalSec = 0.0;

  Hms1000 current, total;
  current.fromSeconds(posSec);
  total.fromSeconds(totalSec);

  string res = format("%02d:%02d:%02d.%03d / %02d:%02d:%02d.%03d",
    current.hours, current.minutes, current.seconds, current.mSeconds,
    total.hours, total.minutes, total.seconds, total.mSeconds);

  if (isLooping)
    res ~= " [LOOP]";
  if (isPaused)
    res ~= " [PAUSED]";
  if (isMuted)
    res ~= " [MUTE]";

  return res;
}

string formatInOut(double timeIn, double timeOut)
{
  if (timeIn < 0.0)
    timeIn = 0.0;
  if (timeOut < 0.0)
    timeOut = 0.0;

  Hms1000 inHms, outHms;
  inHms.fromSeconds(timeIn);
  outHms.fromSeconds(timeOut);

  return format("IN: %02d:%02d:%02d.%03d  OUT: %02d:%02d:%02d.%03d",
    inHms.hours, inHms.minutes, inHms.seconds, inHms.mSeconds,
    outHms.hours, outHms.minutes, outHms.seconds, outHms.mSeconds);
}

string generateFfmpegCutCommand(string inputFilename, double timeIn, double timeOut, double fps)
{
  if (timeIn < 0.0)
    timeIn = 0.0;
  if (timeOut < timeIn)
    timeOut = timeIn;

  double singleFrameDisplayTime = (fps > 0.0) ? (1.0 / fps) : 0.0;
  double duration = (timeOut - timeIn) + singleFrameDisplayTime;
  if (duration < 0.0)
    duration = 0.0;

  Hms1000 inHms, durHms, outHms;
  inHms.fromSeconds(timeIn);
  durHms.fromSeconds(duration);
  outHms.fromSeconds(timeOut);

  string stem = stripExtension(inputFilename);
  string ext = extension(inputFilename);

  string outputFilename = format("%s_%02d%02d%02d_%03d_%02d%02d%02d_%03d_cut%s",
    stem,
    inHms.hours, inHms.minutes, inHms.seconds, inHms.mSeconds,
    outHms.hours, outHms.minutes, outHms.seconds, outHms.mSeconds,
    ext);

  return format(`ffmpeg -ss %02d:%02d:%02d.%03d -i "%s" -t %02d:%02d:%02d.%03d -c:v copy -c:a copy "%s"`,
    inHms.hours, inHms.minutes, inHms.seconds, inHms.mSeconds,
    inputFilename,
    durHms.hours, durHms.minutes, durHms.seconds, durHms.mSeconds,
    outputFilename);
}

unittest
{
  string ts1 = formatTimestamp(12.3456, 125.789);
  assert(ts1 == "00:00:12.345 / 00:02:05.789");

  string ts2 = formatTimestamp(3661.050, 7200.0, true, false);
  assert(ts2 == "01:01:01.050 / 02:00:00.000 [LOOP]");

  string ts3 = formatTimestamp(0.0, 0.0, false, true);
  assert(ts3 == "00:00:00.000 / 00:00:00.000 [PAUSED]");

  string ts4 = formatTimestamp(10.0, 20.0, true, true);
  assert(ts4 == "00:00:10.000 / 00:00:20.000 [LOOP] [PAUSED]");

  string ts5 = formatTimestamp(10.0, 20.0, false, false, true);
  assert(ts5 == "00:00:10.000 / 00:00:20.000 [MUTE]");

  string ts6 = formatTimestamp(10.0, 20.0, true, true, true);
  assert(ts6 == "00:00:10.000 / 00:00:20.000 [LOOP] [PAUSED] [MUTE]");

  string inOut1 = formatInOut(5.0, 25.5);
  assert(inOut1 == "IN: 00:00:05.000  OUT: 00:00:25.500");

  string inOut2 = formatInOut(-1.0, -5.0);
  assert(inOut2 == "IN: 00:00:00.000  OUT: 00:00:00.000");

  string inOut3 = formatInOut(3661.123, 7322.456);
  assert(inOut3 == "IN: 01:01:01.123  OUT: 02:02:02.456");

  string cmd = generateFfmpegCutCommand("samplevideo.mp4", 5.0, 25.0, 25.0);
  assert(cmd == `ffmpeg -ss 00:00:05.000 -i "samplevideo.mp4" -t 00:00:20.040 -c:v copy -c:a copy "samplevideo_000005_000_000025_000_cut.mp4"`);

  string cmdPath = generateFfmpegCutCommand("/path/to/my_video.mkv", 0.0, 10.5, 30.0);
  assert(cmdPath == `ffmpeg -ss 00:00:00.000 -i "/path/to/my_video.mkv" -t 00:00:10.533 -c:v copy -c:a copy "/path/to/my_video_000000_000_000010_500_cut.mkv"`);
}

