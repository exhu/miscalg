module sdlffcd.sdlffcd_sdl;
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
void sdlffcd_app_present(sdlffcd_AppContext* app);
void sdlffcd_app_shutdown(sdlffcd_AppContext* app);
bool sdlffcd_app_need_redraw(const sdlffcd_AppContext* app);
bool sdlffcd_app_check_and_clear_redraw(sdlffcd_AppContext* app);
void sdlffcd_app_set_need_redraw(sdlffcd_AppContext* app, bool need_redraw);
bool sdlffcd_app_get_window_size(const sdlffcd_AppContext* app, int* out_w, int* out_h);
float sdlffcd_app_get_display_scale(const(sdlffcd_AppContext)* app);
bool sdlffcd_app_toggle_fullscreen(sdlffcd_AppContext* app);
bool sdlffcd_app_is_fullscreen(const sdlffcd_AppContext* app);

/* --- Video Renderer API --- */

struct sdlffcd_VideoRenderer;

sdlffcd_VideoRenderer* sdlffcd_video_renderer_create(sdlffcd_AppContext* app);
bool sdlffcd_video_renderer_draw_yuv(sdlffcd_AppContext* app, sdlffcd_VideoRenderer* vr,
                                    const(ubyte*)* data, const(int)* linesize,
                                    int width, int height);
bool sdlffcd_video_renderer_redraw(sdlffcd_AppContext* app, sdlffcd_VideoRenderer* vr);
void sdlffcd_video_renderer_destroy(sdlffcd_VideoRenderer* vr);

/* --- Audio Stream Playback API --- */

struct sdlffcd_AudioStream;

sdlffcd_AudioStream* sdlffcd_audio_stream_open(int sample_rate, int channels);
bool sdlffcd_audio_stream_put_data(sdlffcd_AudioStream* stream, const void* data, int len);
bool sdlffcd_audio_stream_set_paused(sdlffcd_AudioStream* stream, bool paused);
bool sdlffcd_audio_stream_is_paused(const(sdlffcd_AudioStream)* stream);
bool sdlffcd_audio_stream_clear(sdlffcd_AudioStream* stream);
bool sdlffcd_audio_stream_set_volume(sdlffcd_AudioStream* stream, float volume);
bool sdlffcd_audio_stream_get_volume(const(sdlffcd_AudioStream)* stream, float* out_volume);
void sdlffcd_audio_stream_close(sdlffcd_AudioStream* stream);

/* --- Text & Font API --- */

struct sdlffcd_Font;
struct sdlffcd_Text;

enum sdlffcd_FontHinting : int {
    SDLFFCD_FONT_HINTING_NORMAL         = 0,
    SDLFFCD_FONT_HINTING_LIGHT          = 1,
    SDLFFCD_FONT_HINTING_MONO           = 2,
    SDLFFCD_FONT_HINTING_NONE           = 3,
    SDLFFCD_FONT_HINTING_LIGHT_SUBPIXEL = 4
}

sdlffcd_Font* sdlffcd_font_open(const(void)* data, size_t data_size, float ptsize);
bool sdlffcd_font_set_hinting(sdlffcd_Font* font, sdlffcd_FontHinting hinting);
sdlffcd_FontHinting sdlffcd_font_get_hinting(const(sdlffcd_Font)* font);
bool sdlffcd_font_set_size_dpi(sdlffcd_Font* font, float ptsize, int hdpi, int vdpi);
void sdlffcd_font_close(sdlffcd_Font* font);
sdlffcd_Text* sdlffcd_text_create(sdlffcd_AppContext* app, sdlffcd_Font* font, const char* text);
bool sdlffcd_text_set_string(sdlffcd_Text* text_obj, const char* new_text);
bool sdlffcd_text_set_color(sdlffcd_Text* text_obj, ubyte r, ubyte g, ubyte b, ubyte a);
bool sdlffcd_text_get_size(const(sdlffcd_Text)* text_obj, int* out_w, int* out_h);
bool sdlffcd_text_draw(sdlffcd_Text* text_obj, float x, float y);
bool sdlffcd_text_draw_with_bg(sdlffcd_AppContext* app, sdlffcd_Text* text_obj, float x, float y,
                               ubyte bg_r, ubyte bg_g, ubyte bg_b, ubyte bg_a, float padding);
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

    // Video renderer null checks
    assert(sdlffcd_video_renderer_create(null) !is null);
    sdlffcd_VideoRenderer* vr = sdlffcd_video_renderer_create(null);
    assert(!sdlffcd_video_renderer_draw_yuv(null, vr, null, null, 0, 0));
    assert(!sdlffcd_video_renderer_redraw(null, vr));
    sdlffcd_video_renderer_destroy(vr);

    // Audio stream null checks
    assert(sdlffcd_audio_stream_open(0, 0) is null);
    assert(!sdlffcd_audio_stream_put_data(null, null, 0));
    assert(!sdlffcd_audio_stream_set_paused(null, true));
    assert(sdlffcd_audio_stream_is_paused(null));
    assert(!sdlffcd_audio_stream_clear(null));
    assert(!sdlffcd_audio_stream_set_volume(null, 0.5f));
    assert(!sdlffcd_audio_stream_get_volume(null, null));
    sdlffcd_audio_stream_close(null);

    // Text & font null checks
    assert(sdlffcd_font_open(null, 0, 12.0f) is null);
    assert(!sdlffcd_font_set_hinting(null, sdlffcd_FontHinting.SDLFFCD_FONT_HINTING_NORMAL));
    assert(sdlffcd_font_get_hinting(null) == sdlffcd_FontHinting.SDLFFCD_FONT_HINTING_NORMAL);
    assert(!sdlffcd_font_set_size_dpi(null, 12.0f, 96, 96));
    assert(sdlffcd_text_create(null, null, null) is null);
    assert(!sdlffcd_text_set_string(null, null));
    assert(!sdlffcd_text_set_color(null, 255, 255, 255, 255));
    assert(!sdlffcd_text_get_size(null, null, null));
    assert(!sdlffcd_text_draw(null, 0, 0));
    assert(!sdlffcd_text_draw_with_bg(null, null, 0, 0, 0, 0, 0, 0, 0));
    sdlffcd_text_destroy(null);

    // Log null checks
    sdlffcd_log_message(0, sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_INFO, null);
}
