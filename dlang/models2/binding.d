module binding;

/*
  model with versioning
  is updated?
  value?

  app cycle:
    event(init/timer/input/idle) ->
    logic.update (modifies models) ->
    (in case of a game or video just accumulates events
    and updates physics etc at fixed pace later, it's inside logic.update to decide)
    view.update (modifies view models, can depend on logic,
	or other factors, e.g. cursor blinking is not dependent on logic models) ->
    redraw (if view updated, or forced by system)
 */

// TODO deprecate Binding stuff, write Context storing the model, Controller, View storing TrackedModelPointer
// delegates do not make much sense since they allocate memory

/// code that sets element's property/performs action
struct Binding
{
  void delegate() updateValue;
}

/// model that affects multiple dependent properties
struct BoundModel
{
  bool delegate() pollUpdate;
  /// this dynarray changes much when new ui elements are loaded/screens change...
  Binding[] bindings;
  void update()
  {
    foreach(ref b; bindings)
      {
	b.updateValue();
      }
  }
}

/// events that trigger BindingSystem update?
/// mouse movement triggering models update could be too heavy?
/// control can capture keyboard, or mouse, event overhead (can
/// resolve string event to id, id to callback)?
enum EventCategory
  {
    /// some custom event, like a message from a working thread
    message,
    /// kbd/mouse/joystick/touch...
    input,
    /// custom timer
    timer,
    /// window resize, dpi change etc.
    window,
    /// when you need to do something in the idel too, e.g. benchmark maximum fps
    idle,
  }

/// single system for all active models (i.e. not per screen, because pollUpdate cleans version)
/// shared logic+view, view only, and dynamic embedded view models?
/// ViewModel = only for presentation
/// Model = both for presentation and logic
/// CustomizedViewModel / PresentationModel (e.g. by Generated View) = calculated model instance for a component of a view, e.g.
/// calculated values to set on control based on the ViewModel passed:
/// ViewModel: bool buttonEnabled, Customized/Presentation: string buttonStyleName = ViewModel.buttonEnabled ? "normal : "disabled";
/// Should model instances be owned by controllers, or some global storage?
struct BindingSystem
{
  enum UpdateType
  {
    defaultUpdate,
    forceUpdate,
  }
  
  BoundModel[] models;

  /// this must be called everytime there's possibility that any model has updated
  void update(UpdateType updateType = UpdateType.defaultUpdate)
  {
    foreach(ref m; models)
      {
	if (m.pollUpdate() || updateType == UpdateType.forceUpdate)
	  m.update();
      }
  }
}

import observable;
import std.stdio;

struct DialogBox
{
  //bool visible;
  @property void visible(bool b)
  {
    writefln("visible: %s", b);
  }
}

struct LocalizedFields
{
  string warningTitle;
  string errorTitle;
  string informationTitle;
}

alias LocalizedModel= ObservableModel!LocalizedFields;

struct Rect
{
  int x, y, w, h;
}

// draws shadow
struct ShadowComponent
{
  bool on = true;
}

// participates in embedded windowing system (drag etc.)
struct WindowComponent
{
}

// control participates in focusing, different from windowing
struct FocusComponent
{
  // 0 = automatic
  int index;
  // updated by system
  private bool focused;
}

struct TextComponent
{
  void setText(string text) {}
}

struct ModalComponent
{
}

import std.sumtype;
alias UiComponent = SumType!(ShadowComponent, WindowComponent, FocusComponent, TextComponent, ModalComponent);

struct UiControl
{
  Rect rect;
  UiComponent[] components;
}

struct ControlHandle
{
  int id;
}

struct ControlSystem
{
  ControlHandle screenRoot;
  
  UiControl* getControl(in ControlHandle handle)
  {
    return null;
  }

  ControlHandle allocControl()
  {
    return ControlHandle();
  }
}

// resuable dialog template
struct DialogBoxView
{
  TrackedModelPointer!LocalizedModel loc;
  ControlHandle title;

  
  void build(ref ControlSystem cs, in ControlHandle parent, bool isError, TrackedModelPointer!LocalizedModel loc)
  {
    this.loc = loc;
    UiControl *root = cs.getControl(cs.allocControl());
    root.rect.w = 100;
    root.rect.h = 50;
    root.components ~= UiComponent(WindowComponent());
    root.components ~= UiComponent(ShadowComponent());
    root.components ~= UiComponent(ModalComponent());
    // TODO build hierarchy, store handles to controls to set data in update
  }

  void update(bool visible)
  {
    if (loc.pollUpdate())
      {
    // TODO
      }
  }
}

struct MainScreenView
{
  TrackedModelPointer!LocalizedModel loc;
  // TODO need to invent a way to defer complex control hierarchies
  DialogBoxView infoDialog;
  DialogBoxView errorDialog;


  void build(ref ControlSystem cs, in ControlHandle parent, TrackedModelPointer!LocalizedModel loc)
  {
    this.loc = loc;
    infoDialog.build(cs, parent, false, loc);
    errorDialog.build(cs, parent, true, loc);
  }

  void update(bool isError)
  {
    infoDialog.update(!isError);
    errorDialog.update(isError);
  }
}

struct AppContext
{
  // allocated on gc heap for sharing
  LocalizedModel* loc = new LocalizedModel;
}

struct MainScreenController
{
  TrackedModelPointer!LocalizedModel loc;

  ControlSystem cs;
  MainScreenView view;
  BindingSystem bsystem;

  void build(in AppContext ctx)
  {
    view.build(cs, cs.screenRoot, loc);
    
    // looks like you need to have updateNNN methods to make sense of granular model updates
    // otherwise need to complicate by storing pointers/ids to model in the views...
    // also BindingSystem does not make much sense,
    // probably the right approach is to store model in a data context class, and
    // controllers and views store a handle to it with a last read version and update at their own.
    version(none){   
    Binding b;
    b.updateValue = (){
      view.update(loc.model, false);
    };

    BoundModel bmodel;
    bmodel.pollUpdate = &loc.pollUpdate;
    bmodel.bindings ~= b;

    bsystem.models ~= bmodel;

    bsystem.update(BindingSystem.UpdateType.forceUpdate);
    }
  }

  void update()
  {
    bsystem.update();
  }
}

void main()
{
  struct MyFields
  {
    bool yes;
  }

  alias MyModel = ObservableModel!MyFields;
  Tracked!MyModel m;

  DialogBox dlg;

  Binding b;
  b.updateValue = (){
    dlg.visible = m.yes;
  };

  BoundModel bmodel;
  bmodel.pollUpdate = &m.pollUpdate;
  bmodel.bindings ~= b;

  BindingSystem bsystem;
  bsystem.models ~= bmodel;

  writeln("begin");
  m.yes = true;
  bsystem.update();
  m.yes = true;
  bsystem.update();
  m.yes = false;
  bsystem.update();
  m.yes = false;
  bsystem.update();
  m.yes = true;
  bsystem.update();
}
