module sdlffcd.sdlffcd_clib;
extern(C):

struct sdlffcd_AppContext;

enum sdlffcd_Key : uint {
    SDLFFCD_KEY_UNKNOWN = 0,
    SDLFFCD_KEY_RETURN = 13,
    SDLFFCD_KEY_ESCAPE = 27,
    SDLFFCD_KEY_SPACE = ' ',
    SDLFFCD_KEY_LEFTBRACKET = '[',
    SDLFFCD_KEY_RIGHTBRACKET = ']',
    SDLFFCD_KEY_B = 'b',
    SDLFFCD_KEY_E = 'e',
    SDLFFCD_KEY_F = 'f',
    SDLFFCD_KEY_I = 'i',
    SDLFFCD_KEY_L = 'l',
    SDLFFCD_KEY_M = 'm',
    SDLFFCD_KEY_O = 'o',
    SDLFFCD_KEY_P = 'p',
    SDLFFCD_KEY_Q = 'q',
    SDLFFCD_KEY_R = 'r',
    SDLFFCD_KEY_T = 't',
    SDLFFCD_KEY_V = 'v',
    SDLFFCD_KEY_LEFT = 1073741904,
    SDLFFCD_KEY_RIGHT = 1073741903
}

enum sdlffcd_KeyMod : ushort {
    SDLFFCD_KMOD_NONE = 0,
    SDLFFCD_KMOD_SHIFT = (1 << 0),
    SDLFFCD_KMOD_CTRL = (1 << 1),
    SDLFFCD_KMOD_ALT = (1 << 2)
}

alias sdlffcd_KeyCallback = void function(void* userdata, uint key, ushort mod);

enum sdlffcd_WindowEvent : int {
    SDLFFCD_WINDOW_EVENT_NONE = 0,
    SDLFFCD_WINDOW_EVENT_PIXEL_SIZE_CHANGED = 1,
    SDLFFCD_WINDOW_EVENT_DISPLAY_SCALE_CHANGED = 2
}

alias sdlffcd_WindowEventCallback = void function(void* userdata, sdlffcd_WindowEvent event);

sdlffcd_AppContext* sdlffcd_app_init(const char* title, int width, int height);
bool sdlffcd_app_is_running(const sdlffcd_AppContext* app);
void sdlffcd_app_stop(sdlffcd_AppContext* app);
void sdlffcd_app_set_key_callback(sdlffcd_AppContext* app, sdlffcd_KeyCallback cb, void* userdata);
void sdlffcd_app_set_window_event_callback(sdlffcd_AppContext* app, sdlffcd_WindowEventCallback cb, void* userdata);
void sdlffcd_app_poll_events(sdlffcd_AppContext* app);
void sdlffcd_app_wait_events(sdlffcd_AppContext* app, int timeout_ms);
bool sdlffcd_app_wake(sdlffcd_AppContext* app);
void sdlffcd_app_render(sdlffcd_AppContext* app);
void sdlffcd_app_shutdown(sdlffcd_AppContext* app);
bool sdlffcd_app_need_redraw(const sdlffcd_AppContext* app);
bool sdlffcd_app_check_and_clear_redraw(sdlffcd_AppContext* app);
void sdlffcd_app_set_need_redraw(sdlffcd_AppContext* app, bool need_redraw);
bool sdlffcd_app_get_window_size(const sdlffcd_AppContext* app, int* out_w, int* out_h);
bool sdlffcd_app_toggle_fullscreen(sdlffcd_AppContext* app);
bool sdlffcd_app_is_fullscreen(const sdlffcd_AppContext* app);

/* --- Video API --- */

struct sdlffcd_VideoContext;

enum sdlffcd_DecodeStatus : int {
    SDLFFCD_DECODE_ERROR = -1,
    SDLFFCD_DECODE_OK = 0,
    SDLFFCD_DECODE_EOF = 1
}

struct sdlffcd_MediaInfo {
    char[64] format_name;
    char[64] video_codec_name;
    char[64] audio_codec_name;
    double duration_seconds;
    double fps;
    long num_frames;
    int num_streams;
    int video_stream_index;
    int audio_stream_index;
    int width;
    int height;
    int pixel_format;
}

struct sdlffcd_VideoFrame {
    ubyte*[8] data;
    double pts;
    int[8] linesize;
    int width;
    int height;
    int pixel_format;
    ubyte[4] _pad;
}

sdlffcd_VideoContext* sdlffcd_video_open(const char* filename);
bool sdlffcd_video_get_media_info(const sdlffcd_VideoContext* vctx, sdlffcd_MediaInfo* out_info);
sdlffcd_DecodeStatus sdlffcd_video_decode_frame(sdlffcd_VideoContext* vctx, sdlffcd_VideoFrame* out_frame);
bool sdlffcd_video_seek(sdlffcd_VideoContext* vctx, double target_pts_seconds);
bool sdlffcd_video_render_frame(sdlffcd_AppContext* app, sdlffcd_VideoContext* vctx, const(sdlffcd_VideoFrame)* frame);
bool sdlffcd_video_redraw(sdlffcd_AppContext* app, sdlffcd_VideoContext* vctx);
void sdlffcd_video_close(sdlffcd_VideoContext* vctx);

/* --- Audio API --- */

bool sdlffcd_video_has_audio(const(sdlffcd_VideoContext)* vctx);
bool sdlffcd_video_set_audio_paused(sdlffcd_VideoContext* vctx, bool paused);
bool sdlffcd_video_is_audio_paused(const(sdlffcd_VideoContext)* vctx);
bool sdlffcd_video_clear_audio(sdlffcd_VideoContext* vctx);
bool sdlffcd_video_set_audio_volume(sdlffcd_VideoContext* vctx, float volume);
bool sdlffcd_video_get_audio_volume(const(sdlffcd_VideoContext)* vctx, float* out_volume);

/* --- Text API --- */

struct sdlffcd_Font;
struct sdlffcd_Text;

enum sdlffcd_FontHinting : int {
    SDLFFCD_FONT_HINTING_NORMAL         = 0,
    SDLFFCD_FONT_HINTING_LIGHT          = 1,
    SDLFFCD_FONT_HINTING_MONO           = 2,
    SDLFFCD_FONT_HINTING_NONE           = 3,
    SDLFFCD_FONT_HINTING_LIGHT_SUBPIXEL = 4
}

void sdlffcd_app_present(sdlffcd_AppContext* app);
float sdlffcd_app_get_display_scale(const(sdlffcd_AppContext)* app);
sdlffcd_Font* sdlffcd_font_open(const char* filepath, float ptsize);
bool sdlffcd_font_set_hinting(sdlffcd_Font* font, sdlffcd_FontHinting hinting);
sdlffcd_FontHinting sdlffcd_font_get_hinting(const(sdlffcd_Font)* font);
bool sdlffcd_font_set_size_dpi(sdlffcd_Font* font, float ptsize, int hdpi, int vdpi);
void sdlffcd_font_close(sdlffcd_Font* font);
sdlffcd_Text* sdlffcd_text_create(sdlffcd_AppContext* app, sdlffcd_Font* font, const char* text);
bool sdlffcd_text_set_string(sdlffcd_Text* text_obj, const char* new_text);
bool sdlffcd_text_set_color(sdlffcd_Text* text_obj, ubyte r, ubyte g, ubyte b, ubyte a);
bool sdlffcd_text_get_size(const(sdlffcd_Text)* text_obj, int* out_w, int* out_h);
bool sdlffcd_text_draw(sdlffcd_Text* text_obj, float x, float y);
bool sdlffcd_text_draw_with_bg(sdlffcd_AppContext* app, sdlffcd_Text* text_obj, float x, float y, ubyte bg_r, ubyte bg_g, ubyte bg_b, ubyte bg_a, float padding);
void sdlffcd_text_destroy(sdlffcd_Text* text_obj);

/* --- Log API --- */

enum sdlffcd_LogPriority : int {
    SDLFFCD_LOG_PRIORITY_TRACE    = 1,
    SDLFFCD_LOG_PRIORITY_VERBOSE  = 2,
    SDLFFCD_LOG_PRIORITY_DEBUG    = 3,
    SDLFFCD_LOG_PRIORITY_INFO     = 4,
    SDLFFCD_LOG_PRIORITY_WARN     = 5,
    SDLFFCD_LOG_PRIORITY_ERROR    = 6,
    SDLFFCD_LOG_PRIORITY_CRITICAL = 7
}

void sdlffcd_log_message(int category, sdlffcd_LogPriority priority, const char* message);
void sdlffcd_log_set_all_priority(sdlffcd_LogPriority priority);

extern(D) unittest
{
    assert(sdlffcd_Key.SDLFFCD_KEY_UNKNOWN == 0);
    assert(sdlffcd_Key.SDLFFCD_KEY_RETURN == 13);
    assert(sdlffcd_Key.SDLFFCD_KEY_ESCAPE == 27);
    assert(sdlffcd_Key.SDLFFCD_KEY_SPACE == ' ');
    assert(sdlffcd_Key.SDLFFCD_KEY_LEFTBRACKET == '[');
    assert(sdlffcd_Key.SDLFFCD_KEY_RIGHTBRACKET == ']');
    assert(sdlffcd_Key.SDLFFCD_KEY_B == 'b');
    assert(sdlffcd_Key.SDLFFCD_KEY_E == 'e');
    assert(sdlffcd_Key.SDLFFCD_KEY_F == 'f');
    assert(sdlffcd_Key.SDLFFCD_KEY_I == 'i');
    assert(sdlffcd_Key.SDLFFCD_KEY_L == 'l');
    assert(sdlffcd_Key.SDLFFCD_KEY_M == 'm');
    assert(sdlffcd_Key.SDLFFCD_KEY_O == 'o');
    assert(sdlffcd_Key.SDLFFCD_KEY_P == 'p');
    assert(sdlffcd_Key.SDLFFCD_KEY_Q == 'q');
    assert(sdlffcd_Key.SDLFFCD_KEY_R == 'r');
    assert(sdlffcd_Key.SDLFFCD_KEY_T == 't');
    assert(sdlffcd_Key.SDLFFCD_KEY_V == 'v');
    assert(sdlffcd_Key.SDLFFCD_KEY_LEFT == 1073741904);
    assert(sdlffcd_Key.SDLFFCD_KEY_RIGHT == 1073741903);

    assert(sdlffcd_KeyMod.SDLFFCD_KMOD_NONE == 0);
    assert(sdlffcd_KeyMod.SDLFFCD_KMOD_SHIFT == 1);
    assert(sdlffcd_KeyMod.SDLFFCD_KMOD_CTRL == 2);
    assert(sdlffcd_KeyMod.SDLFFCD_KMOD_ALT == 4);

    assert(sdlffcd_WindowEvent.SDLFFCD_WINDOW_EVENT_NONE == 0);
    assert(sdlffcd_WindowEvent.SDLFFCD_WINDOW_EVENT_PIXEL_SIZE_CHANGED == 1);
    assert(sdlffcd_WindowEvent.SDLFFCD_WINDOW_EVENT_DISPLAY_SCALE_CHANGED == 2);

    assert(sdlffcd_FontHinting.SDLFFCD_FONT_HINTING_NORMAL == 0);
    assert(sdlffcd_FontHinting.SDLFFCD_FONT_HINTING_LIGHT == 1);
    assert(sdlffcd_FontHinting.SDLFFCD_FONT_HINTING_MONO == 2);
    assert(sdlffcd_FontHinting.SDLFFCD_FONT_HINTING_NONE == 3);
    assert(sdlffcd_FontHinting.SDLFFCD_FONT_HINTING_LIGHT_SUBPIXEL == 4);

    assert(sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_TRACE == 1);
    assert(sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_VERBOSE == 2);
    assert(sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_DEBUG == 3);
    assert(sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_INFO == 4);
    assert(sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_WARN == 5);
    assert(sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_ERROR == 6);
    assert(sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_CRITICAL == 7);

    assert(!sdlffcd_app_need_redraw(null));
    assert(!sdlffcd_app_check_and_clear_redraw(null));
    sdlffcd_app_set_need_redraw(null, true);
    sdlffcd_app_set_key_callback(null, null, null);
    sdlffcd_app_set_window_event_callback(null, null, null);
    assert(!sdlffcd_app_get_window_size(null, null, null));
    assert(sdlffcd_app_get_display_scale(null) == 1.0f);
    assert(!sdlffcd_app_toggle_fullscreen(null));
    assert(!sdlffcd_app_is_fullscreen(null));
    assert(!sdlffcd_video_redraw(null, null));

    // Verify null handling for audio API functions
    assert(!sdlffcd_video_has_audio(null));
    assert(!sdlffcd_video_set_audio_paused(null, true));
    assert(sdlffcd_video_is_audio_paused(null));
    assert(!sdlffcd_video_clear_audio(null));
    assert(!sdlffcd_video_set_audio_volume(null, 0.5f));
    assert(!sdlffcd_video_get_audio_volume(null, null));

    // Verify null handling for text API functions
    assert(sdlffcd_font_open(null, 12.0f) is null);
    assert(!sdlffcd_font_set_hinting(null, sdlffcd_FontHinting.SDLFFCD_FONT_HINTING_NORMAL));
    assert(sdlffcd_font_get_hinting(null) == sdlffcd_FontHinting.SDLFFCD_FONT_HINTING_NORMAL);
    assert(!sdlffcd_font_set_size_dpi(null, 12.0f, 96, 96));
    assert(sdlffcd_text_create(null, null, null) is null);
    assert(!sdlffcd_text_set_string(null, null));
    assert(!sdlffcd_text_set_color(null, 255, 255, 255, 255));
    assert(!sdlffcd_text_get_size(null, null, null));
    assert(!sdlffcd_text_draw(null, 0, 0));
    assert(!sdlffcd_text_draw_with_bg(null, null, 0, 0, 0, 0, 0, 0, 0));

    // Verify null handling for log API functions
    sdlffcd_log_message(0, sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_INFO, null);
}
