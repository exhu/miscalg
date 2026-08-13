module sdlffcd.models;

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
