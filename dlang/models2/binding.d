module binding;

/*
  model with versioning
  is updated?
  value?
 */

/// code that sets element's property/performs action
struct Binding
{
  void delegate() updateValue;
}

/// model that affects multiple dependent properties
struct BoundModel
{
  bool delegate() isUpdated;
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

/// single system for all active models (i.e. not per screen, because pollUpdate cleans version)
struct BindingSystem
{
  BoundModel[] models;

  /// this must be called everytime there's possibility that any model has updated
  void update()
  {
    foreach(ref m; models)
      {
	if (m.isUpdated())
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
  bmodel.isUpdated = &m.pollUpdate;
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
