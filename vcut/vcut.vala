
private sealed class VCutApp : Gtk.Application {
  public VCutApp() {
    Object(application_id: "org.vcut", flags: ApplicationFlags.HANDLES_OPEN); // | ApplicationFlags.HANDLES_COMMAND_LINE);
    vcutc = null;
    ui = new Controls();
    vcutExec = new VcutExec();
    vcutExec.on_finished.connect((status) => {
      unmark_busy();
      ui.spinner.active = false;
      ui.set_sensitive(true);
    });
    vcutExec.on_new_line.connect((line) => {
      ui.ffmpeg_text.text += line;
    });
  }

  // overridden methods

  protected override void activate() {
    make_windows();
  }

  protected override void open (File[] files, string hint) {
    make_windows();
    data.input_file = files[0];
    data.output_file = File.new_for_path(get_output_filename());
    string fullname = data.input_file.get_path();
    main_window.title = "vcut - %s".printf(fullname);
    player_window.title = fullname;

    Idle.add(() => {
      Vcutc.open_file(vcutc, data.input_file.get_path());
      return false;
    });
  }

  protected override void shutdown() {
    Vcutc.free_mpv(out vcutc);
    base.shutdown();
  }

  // private methods

  private void ensure_correct_markers() {
    if (data.mark_a_secs > data.mark_b_secs) {
      double temp = data.mark_a_secs;
      data.mark_a_secs = data.mark_b_secs;
      data.mark_b_secs = temp;
    }
  }

  private void update_marker_labels() {
    ui.mark_a_label.set_label(text_from_secs(data.mark_a_secs));
    ui.mark_b_label.set_label(text_from_secs(data.mark_b_secs));
    update_ffmpeg_text();
  }

  private void update_ffmpeg_text() {
    ui.ffmpeg_text.text = generate_ffmpeg_cmd();
  }


  private void create_main_window() {
    main_window = (Gtk.ApplicationWindow)ui.builder.get_object("main_window");
    main_window.show_all();
    add_window(main_window);
    ui.scale = (Gtk.Scale)ui.builder.get_object("time_scale");
    ui.scale.change_value.connect ((scroll, new_value) => {
      Vcutc.seek(vcutc, new_value);
      return true;
    });

    ui.add_clicked("play_pause", () => {
      Vcutc.play_pause(vcutc);
    });

    ui.time_label = (Gtk.Label)ui.builder.get_object("time_label");
    ui.mark_a_label = (Gtk.Label)ui.builder.get_object("a_time");
    ui.mark_b_label = (Gtk.Label)ui.builder.get_object("b_time");
    ui.ffmpeg_text = (Gtk.TextBuffer)ui.builder.get_object("ffmpeg_text");
    ui.spinner = (Gtk.Spinner)ui.builder.get_object("spinner");

    ui.add_clicked("mark_a", () => {
      data.mark_a_secs = Vcutc.get_film_position(vcutc);
      ensure_correct_markers();
      update_marker_labels();
    });

    ui.add_clicked("mark_b", () => {
      data.mark_b_secs = Vcutc.get_film_position(vcutc);
      ensure_correct_markers();
      update_marker_labels();
    });

    ui.add_clicked("prev", () => {
      Vcutc.seek_sec_relative(vcutc, -1.0);
    });

    ui.add_clicked("next", () => {
      Vcutc.seek_sec_relative(vcutc, 1.0);
    });

    ui.add_clicked("begin", () => {
      Vcutc.seek(vcutc, 0.0);
    });

    ui.add_clicked("end", () => {
      Vcutc.seek(vcutc, 1.0);
    });

    ui.add_clicked("play_ab", () => {
      Vcutc.ab_loop(vcutc, data.mark_a_secs, data.mark_b_secs);
    });

    ui.add_clicked("execute", () => {
      if (data.input_file == null) {
        return;
      }

      if (data.output_file.query_exists()) {
        var dlg = new Gtk.MessageDialog(main_window, Gtk.DialogFlags.MODAL | Gtk.DialogFlags.DESTROY_WITH_PARENT,
          Gtk.MessageType.QUESTION, Gtk.ButtonsType.YES_NO,"Overwrite '%s'?", data.output_file.get_path());
        dlg.response.connect((response) => {
          if (response == Gtk.ResponseType.YES) {
            exec_ffmpeg();
          }
          dlg.destroy();
        });
        dlg.run();
      } else {
        exec_ffmpeg();
      }
    });
  }

  private string get_output_filename() {
    if (data.input_file != null) {
      string filename = data.input_file.get_path();
      int ext_index = filename.last_index_of(".");
      string ext = ext_index >= 0 ? filename.substring(ext_index) : ""; 
      return filename.substring(0, ext_index) + "_cut" + ext;
    }
    return "";
  }

  private string[] generate_ffmpeg_spawn_args(bool overwrite = false) {
    // ffmpeg -ss "$START" -i "$INPUT" "$@" -acodec copy -vcodec copy -t "$DURATION" "$OUTPUT"
    if (data.input_file != null) {
      Array<string> array = new Array<string>();
      array.append_val("ffmpeg");

      if (overwrite) {
        array.append_val("-y");
      }

      string[] str_args = {"-ss", ((int)Math.floor(data.mark_a_secs)).to_string(),
        "-i", data.input_file.get_path(),
        "-acodec", "copy", "-vcodec", "copy",
        "-t", ((int)Math.ceil(data.mark_b_secs - data.mark_a_secs + 1.0)).to_string(),
        data.output_file.get_path()
      };

      array.append_vals(str_args, str_args.length);
      return array.data;
    }
    return {""};
  }

  private string generate_ffmpeg_cmd(bool overwrite = false) {
    string outtext = "";
    if (data.input_file != null) {
      string output_filename = data.output_file.get_path();
      outtext = "ffmpeg %s -ss %i -i '%s' -acodec copy -vcodec copy -t %i '%s'\n".printf(
        overwrite ? "-y" : "",
        (int)Math.floor(data.mark_a_secs),
        data.input_file.get_path(),
        (int)Math.ceil(data.mark_b_secs - data.mark_a_secs + 1.0),
        output_filename);
    }
    return outtext;
  }

  private static string text_from_secs(double secs) {
      int total_secs = (int)secs;
      int h = total_secs/(60*60);
      int m = (total_secs/60)%60;
      int s = total_secs%60;

      string time_text = "%.2i:%.2i:%.2i".printf(h, m, s);
      return time_text;
  }

  private void create_player_window() {
    data.film_duration = 0;
    data.mark_a_secs = 0;
    data.mark_b_secs = 0;

    player_window = (Gtk.Window)ui.builder.get_object("player_window");

    player_window.delete_event.connect(() => {
      return true;
    });
    player_window.destroy.connect(() => {
      Vcutc.free_mpv(out vcutc);
    });

    Gtk.DrawingArea drawArea = new Gtk.DrawingArea();
    player_window.add(drawArea);
    player_window.show_all();

    Gdk.Window gdkwin = drawArea.get_parent_window();
    assert(gdkwin.has_native());
//    assert(gdkwin is Gdk.X11.Window);
    X.Window x11wnd = ((Gdk.X11.Window)gdkwin).get_xid();

    Vcutc.init_mpv(x11wnd, out vcutc, (new_time) => {
      ui.scale.set_value(new_time/data.film_duration);
      ui.time_label.set_label(text_from_secs(new_time)); 
    });

    Vcutc.set_file_loaded_cb(vcutc, () => {
      data.film_duration = Vcutc.get_film_duration(vcutc);
    });
  }

  private void make_windows() {
    ui.builder = new Gtk.Builder();
    try {
      //builder.add_from_file("vcut_gui.glade");
      ui.builder.add_from_resource("/org/exhu/vcut/vcut_gui.glade");
    }
    catch(Error e) {
      stdout.printf("failed to read gui file! %s\n", e.message);
      Process.exit(1);
    }
    create_main_window();
    create_player_window();
  }

  private void exec_ffmpeg() {
    Vcutc.set_pause(vcutc, true);
    update_ffmpeg_text();
    var args = generate_ffmpeg_spawn_args(true);
    mark_busy();
    ui.spinner.active = true;
    ui.set_sensitive(false);
    vcutExec.run(args);
  }

  // data members

  class Controls {
    public Gtk.Scale scale;
    public Gtk.Builder builder;
    public Gtk.Label time_label;
    public Gtk.TextBuffer ffmpeg_text;
    public Gtk.Label mark_a_label;
    public Gtk.Label mark_b_label;
    public Gtk.Spinner spinner;
    public Array<Gtk.Button> buttons;

    public Controls() {
      buttons = new Array<Gtk.Button>();
    }

    public void set_sensitive(bool b) {
      scale.set_sensitive(b);
      foreach(var btn in buttons.data) {
        btn.set_sensitive(b);
      }
    }

    public delegate void OnClicked();
    public void add_clicked(string btn_name, OnClicked cb) {
      Gtk.Button btn = (Gtk.Button)builder.get_object(btn_name);
      btn.clicked.connect(() => {
        cb();
      });
      buttons.append_val(btn);
    }
  }

  Controls ui;

  struct Model {
    File input_file;
    File output_file;
    double film_duration; // secs
    double mark_a_secs;
    double mark_b_secs;
  }

  Model data;

  Gtk.ApplicationWindow main_window;
  Gtk.Window player_window;
  Vcutc.VcutC *vcutc;
  VcutExec vcutExec;
}


int main(string[] args) {
  VCutApp app = new VCutApp();
  return app.run(args);
}
