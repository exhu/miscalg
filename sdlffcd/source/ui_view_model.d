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

struct View
{
  void update(in ViewModel m)
  {
    // TODO redraw
  }
}

struct Controller
{
  View view;
  ViewModel viewModel;
  PlayerModel playerModel;
  ModelVersion playerModelVersion;
  EditModel editModel;
  ModelVersion editModelVersion;

  // TODO refactor versionUpdated -- repetitive and can introduce mistake (versions of different models)
  void update()
  {
    bool dirty = false;
    if (versionUpdated(playerModelVersion, playerModel.version_))
    {
      dirty = true;
      viewModel.formattedCurrentTotalTime = formatTimestamp(playerModel.timePosition, playerModel
          .timeDuration);
    }
    if (versionUpdated(editModelVersion, editModel.version_))
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
  /// updates old version if older, and returns true.
  bool versionUpdated(ref ModelVersion old, in ModelVersion current)
  {
    if (old != current)
    {
      old = current;
      return true;
    }
    return false;
  }

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

/** This depends on Model, and also controls display mode, e.g. timestamp position which is
    cycled by key press.
*/
struct ViewModel
{
  string formattedCurrentTotalTime;
  TimePosition timePosition;
}

/** Some values that a retrieved/changed in VideoPlayer and other lower components
   are replicated in the Model as a logic update step. So the model depends
   on the state of the program.
 */
private struct PlayerFields
{
  bool isPaused;
  bool isLooping;
  double timePosition;
  double timeDuration;
}

alias PlayerModel = ObservableModel!PlayerFields;

private struct EditFields
{
  /// In cut point (always less than timeDuration)
  double timeIn;
  /// Out cut point (the time of the beginning of the frame), always less than timeDuration
  double timeOut;
}

alias EditModel = ObservableModel!EditFields;

import std.traits : FieldNameTuple;

alias ModelVersion = size_t;

template ObservableModel(T) if (is(T == struct))
{
  struct ObservableModel
  {
    // Encapsulated underlying model instance
    private T model;
    // 0 is used to mark uninitialized
    private ModelVersion _version = 1;

    /// Read-only version counter tracking modifications
    @property ModelVersion version_() const @safe pure nothrow @nogc
    {
      return _version;
    }

    // Generate getters and setters for each field in the source struct
    static foreach (fieldName; FieldNameTuple!T)
    {
      // Public Getter
      mixin("@property auto ", fieldName, "() const @safe pure nothrow @nogc { return model.", fieldName, "; }");

      // Public Setter (increments version_ on change)
      mixin("@property void ", fieldName, "(typeof(T.", fieldName, ") value) @safe { ",
        "if (model.", fieldName, " != value) { ",
        "model.", fieldName, " = value; ",
        "_version++;",
        "} ",
        "}");
    }
  }
}

unittest
{
  struct MyFields
  {
    bool yes;
  }

  alias MyModel = ObservableModel!MyFields;
  MyModel m;
  assert(m.version_ == 1);
  m.yes = true;
  assert(m.version_ == 2);
  m.yes = true;
  assert(m.version_ == 2);
  m.yes = false;
  assert(m.version_ == 3);
}
