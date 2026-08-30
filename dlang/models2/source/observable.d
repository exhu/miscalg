module observable;

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

template ObservableModelClass(T) if (is(T == struct))
{
  final class ObservableModelClass
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

  alias MyModel = ObservableModelClass!MyFields;
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
  alias MyModel = ObservableModel!MyFields;
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
  alias MyModel = ObservableModel!MyFields;
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
