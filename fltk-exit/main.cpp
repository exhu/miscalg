#include <FL/Fl.H>
#include <FL/Fl_Box.H>
#include <FL/Fl_Double_Window.H>
#include <FL/Fl_Window.H>
#include <FL/fl_ask.H>

#include <functional>
#include <list>
#include <optional>

enum class ViewEvent {
  windowClose,
  confirmationDialogYes,
  confirmationDialogNo,
};

std::list<ViewEvent> eventQueue;

static void awake_cb(void *);

void pushEvent(ViewEvent e) {
  eventQueue.push_back(e);
  // TODO should not awake if already sent
  Fl::awake(&awake_cb, nullptr);
}

std::optional<ViewEvent> pullEvent() {
  if (eventQueue.empty())
    return {};
  auto ret = eventQueue.front();
  eventQueue.pop_front();
  return ret;
}

struct ViewModelFields {
  bool showExitConfirmationDialog = false;
};

class ViewModel {
public:
  int version() const { return fVersion; }
  const ViewModelFields &fields() const { return fFields; }

  void mutate(std::function<bool(ViewModelFields &)> func) {
    if (func(fFields))
      fVersion += 1;
  }

private:
  int fVersion = 1;
  ViewModelFields fFields;
};

struct View {
  Fl_Widget *widget = nullptr;
  ViewModel *model = nullptr;
  int modelVersion = 0;

  void update() {
    if (modelVersion == model->version())
      return;
    modelVersion = model->version();
    if (model->fields().showExitConfirmationDialog) {
      int choice = fl_choice("Are you sure you want to exit?", "No", "Yes", 0);
      pushEvent(choice == 1 ? ViewEvent::confirmationDialogYes
                            : ViewEvent::confirmationDialogNo);
    }
  }

  void close() { widget->hide(); }
};

ViewModel gViewModel;
View gView;

static void onWindowClose() {
  gViewModel.mutate([](ViewModelFields &fields) {
    fields.showExitConfirmationDialog = true;
    return true;
  });
}

static void onDialogNo() {
  gViewModel.mutate([](ViewModelFields &fields) {
    fields.showExitConfirmationDialog = false;
    return true;
  });
}

static void onDialogYes() {
  gViewModel.mutate([](ViewModelFields &fields) {
    fields.showExitConfirmationDialog = false;
    return true;
  });
  gView.close();
}

static void controllerUpdate() {
  while (std::optional<ViewEvent> ev = pullEvent()) {
    switch (ev.value()) {
    case ViewEvent::windowClose:
      onWindowClose();
      break;
    case ViewEvent::confirmationDialogNo:
      onDialogNo();
      break;
    case ViewEvent::confirmationDialogYes:
      onDialogYes();
      break;
    }
  }
}

static void awake_cb(void *) {
  controllerUpdate();
  gView.update();
}

// Callback function triggered when the user attempts to close the window
void window_close_cb(Fl_Widget *, void *) {
  pushEvent(ViewEvent::windowClose);
}

int main(int argc, char **argv) {
  Fl::lock();
  Fl_Double_Window *win =
      new Fl_Double_Window(400, 200, "Exit Confirmation Demo");

  gView.widget = win;
  gView.model = &gViewModel;

  Fl_Box *box =
      new Fl_Box(20, 40, 360, 100, "Close the window to trigger confirmation.");
  box->labelsize(14);

  win->end();

  // Intercept window close events
  win->callback(window_close_cb);

  win->show(argc, argv);
  return Fl::run();
}
