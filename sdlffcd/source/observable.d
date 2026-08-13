module sdlffcd.observable;

import std.traits : FieldNameTuple;

alias ModelVersion = size_t;
enum ModelVersion uninitializedVersion = 0;

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

struct Tracked(T)
{
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

  alias MyModel = ObservableModel!MyFields;
  Tracked!MyModel m;
  m.yes = true;
  assert(m.pollUpdate() == true);
  m.yes = true;
  assert(m.pollUpdate() == false);
  m.yes = false;
  assert(m.pollUpdate() == true);
}
