module observable;

/*
  poll ui architecture:
  view receives models, exposes event callbacks for controller
  view events, and other controller subscribed events enque controller.update, which
  calls view.update, which calls pollUpdate for all models.

  view abstracts gui/tui implementation.

  view is top-level abstraction that is setup and has subscribed by the controller
  subview is a reusable view fragment, which propagates events to it's parent view,
  e.g. a reusable form/dialog that accepts it's own smaller model and generates some events
  which are exported then via parent view.

  view and subview may contain private models and logic code which drive the presentation,
  e.g. accept an integer value and based on the value calculate a colour. 

 */



import std.traits : FieldNameTuple;

alias ModelVersion = size_t;

template VersionedModel(T) if (is(T == struct))
{
  struct VersionedModel
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

// replaced with opDispatch

version(none) {

template VersionedModelClass(T) if (is(T == struct))
{
  final class VersionedModelClass
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

}

template VersionedModelClass(T) if (is(T == struct))
{
    import std.traits : FieldNameTuple, hasMember;

    final class VersionedModelClass
    {
        private T model;
        private ModelVersion _version = 1;

        @property ModelVersion version_() const @safe pure nothrow @nogc
        {
            return _version;
        }

        // Getter
        @property auto ref opDispatch(string name)() const @safe
            if (hasMember!(T, name))
        {
            return __traits(getMember, model, name);
        }

        // Setter (increments version if value changed)
        @property void opDispatch(string name, V)(auto ref V value) @safe
            if (hasMember!(T, name) && is(typeof(__traits(getMember, model, name) = value)))
        {
            if (__traits(getMember, model, name) != value)
            {
                __traits(getMember, model, name) = value;
                _version++;
            }
        }
    }
}

template VersionedModelClassLight(T) if (is(T == struct))
{
    final class VersionedModelClassLight
    {
        private T _model;
        private ModelVersion _version = 1;

        @property ModelVersion version_() const @safe pure nothrow @nogc
        {
            return _version;
        }

	@property const(T)* fields() const
	{
	    return &_model;
	}

      void mutate(bool delegate(ref T aFields) func)
    {
      if (func(_model))
	{
	  _version += 1;
	}
    }
    }
}

/*
  gui sends events, e.g. fltk callbacks on button press, slider/scroll.
  model is modified.
  need to update ui, but when? via a posted event to the event loop!

  event-get: mouse click
  button-on-click: send-update-domain-event
  event-get: update-domain
  update domain model, if changed: send-update-view-event
  event-get: update-view
  check which domain models diverged from view versions, update ui

  example:

  exit -> confirmation dialog -> exit, cancel

  topviewmodel {
  bool exit_dialog_visible = false;
  }

  view: event_ui_menu_exit clicked
  logic: event_show_exit_dialog -- event by domain logic for domain logic, or model changed inplace
  logic: topviewmodel.exit_dialog_visible = true;
  view: topviewmodel.changed? message_box("exit?", yesno);
  view: event_ui_exit_confirm or event_ui_exit_cancel
  logic: app.exit()

  main loop gets input events and delivers to ui
  ui callbacks push events to ringbuffer and sends one wake main loop command
  main loop gets wake event, calls update_data
  update_data pulls all events from ringbuffer and updates models, calls update_view
  update_view calls current view instances to update
  current view instances check if their model version is out of date and issue ui calls


  fltks example:
  view recieves model pointer, constructs window or displays a dialog box based on the model dataCaches
  on window close sends event_window_close fl::awake
 */

struct Tracked(T)
{
    this(ref return scope inout(typeof(this)) rhs) inout
    {
	model = rhs.model;
    }

    this(T otherModel)
    {
	model = otherModel;
    }

    T model;
    ModelVersion lastSeenVersion;

    /// Checks if the inner model version has changed, updating the tracker automatically.
    bool pollUpdate()
    {
        if (lastSeenVersion != model.version_)
        {
            lastSeenVersion = model.version_;
            return true;
        }
        return false;
    }

    // Forward calls/member access directly to model
    alias model this;
}

unittest
{
  struct MyFields
  {
    bool yes;
  }

  alias MyModel = VersionedModelClass!MyFields;
  auto m = new MyModel;
  assert(m.version_ == 1);
  m.yes = true;
  assert(m.version_ == 2);
  m.yes = true;
  assert(m.version_ == 2);
  m.yes = false;
  assert(m.version_ == 3);

  auto t = Tracked!MyModel(m);
  t.yes = true;
  assert(t.pollUpdate() == true);
  t.yes = true;
  assert(t.pollUpdate() == false);
  t.yes = false;
  assert(t.pollUpdate() == true);
}


struct TrackedModelPointer(T)
{
    T* model;
    private ModelVersion lastSeenVersion;

  this(T* otherModel)
  {
    model = otherModel;
  }

  this(ref return scope inout(typeof(this)) rhs) inout
  {
    model = rhs.model;
  }

    /// Checks if the inner model version has changed, updating the tracker automatically.
    bool pollUpdate()
    {
        if (lastSeenVersion != model.version_)
        {
            lastSeenVersion = model.version_;
            return true;
        }
        return false;
    }

    // Forward calls/member access directly to model
    alias model this;
}

unittest
{
  struct MyFields
  {
    bool yes;
  }
  alias MyModel = VersionedModel!MyFields;
  Tracked!MyModel t;
  t.yes = true;
  assert(t.pollUpdate() == true);
  t.yes = true;
  assert(t.pollUpdate() == false);
  t.yes = false;
  assert(t.pollUpdate() == true);
}

unittest
{
  struct MyFields
  {
    bool yes;
  }
  alias MyModel = VersionedModel!MyFields;
  alias MyModelTrackedPointer = TrackedModelPointer!MyModel;
  Tracked!MyModel m;
  m.yes = true;
  assert(m.pollUpdate() == true);
  m.yes = true;
  assert(m.pollUpdate() == false);
  m.yes = false;
  assert(m.pollUpdate() == true);

  MyModelTrackedPointer mp = MyModelTrackedPointer(new MyModel);
  mp.yes = true;
  assert(mp.pollUpdate() == true);
  mp.yes = true;
  assert(mp.pollUpdate() == false);
  mp.yes = false;
  assert(mp.pollUpdate() == true);

  MyModelTrackedPointer mp2 = mp;
  
  assert(mp.pollUpdate() == false);
  assert(mp2.pollUpdate() == true);
  assert(mp2.pollUpdate() == false);
  mp2.yes = true;
  assert(mp.pollUpdate() == true);
  assert(mp2.pollUpdate() == true);
}
