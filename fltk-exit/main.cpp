
#include <FL/Fl.H>
#include <FL/Fl_Box.H>
#include <FL/Fl_Double_Window.H>
#include <FL/Fl_Window.H>
#include <FL/fl_ask.H>

struct Context {
  Fl_Widget *widget;
  int choice;
} choiceContext;

static void on_confirmation_cb(void *user) {
  Context *ctx = static_cast<Context *>(user);

  if (ctx->choice == 1) {
    // Hide the window to exit the main event loop cleanly
    ctx->widget->hide();
  }

  // If choice == 0 ("No"), do nothing; the window stays open
}
static void on_close_cb(void *user) {
  Fl_Widget *widget = static_cast<Fl_Widget *>(user);
  // fl_choice returns the index of the clicked button (0 for "No", 1 for "Yes")
  int choice = fl_choice("Are you sure you want to exit?", "No", "Yes", 0);
  choiceContext.choice = choice;
  choiceContext.widget = widget;

  Fl::awake(&on_confirmation_cb, &choiceContext);
}

// Callback function triggered when the user attempts to close the window
void window_close_cb(Fl_Widget *widget, void *data) {
  Fl::awake(&on_close_cb, widget);
}

int main(int argc, char **argv) {
  Fl::lock();
  Fl_Double_Window *win =
      new Fl_Double_Window(400, 200, "Exit Confirmation Demo");

  Fl_Box *box =
      new Fl_Box(20, 40, 360, 100, "Close the window to trigger confirmation.");
  box->labelsize(14);

  win->end();

  // Intercept window close events
  win->callback(window_close_cb);

  win->show(argc, argv);
  return Fl::run();
}
