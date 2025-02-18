[CCode(cheader_filename = "vcutc.h")]
namespace Vcutc { 
    [CCode(cname = "VcutC")]
    struct VcutC
    {

    }
    [CCode (cname = "time_pos_change_cb_t")]
    public delegate void time_pos_change_cb_t(double new_time);
    [CCode (cname = "file_loaded_cb_t")]
    public delegate void file_loaded_cb_t();

    bool init_mpv(int64 wnd, out VcutC *v, time_pos_change_cb_t cb);
    void free_mpv(out VcutC *v);
    void open_file(VcutC *v, string? fn);
    void play_pause(VcutC *v);
    double get_film_duration(VcutC *v);
    void set_file_loaded_cb(VcutC *v, file_loaded_cb_t cb);
    void seek(VcutC *v, double percent_pos);
    double get_film_position(VcutC *v);
    void seek_sec_relative(VcutC *v, double sec_pos);
    void ab_loop(VcutC *v, double start, double end);
    void set_pause(VcutC *v, bool paused);
}


