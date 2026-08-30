import std.stdio;
import binding, observable;

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
