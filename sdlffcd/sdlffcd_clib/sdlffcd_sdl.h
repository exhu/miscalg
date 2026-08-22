#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/* --- Window, Events & Application API --- */

typedef struct sdlffcd_AppContext sdlffcd_AppContext;

typedef enum sdlffcd_Key {
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
} sdlffcd_Key;

typedef enum sdlffcd_KeyMod {
    SDLFFCD_KMOD_NONE = 0,
    SDLFFCD_KMOD_SHIFT = (1 << 0),
    SDLFFCD_KMOD_CTRL = (1 << 1),
    SDLFFCD_KMOD_ALT = (1 << 2)
} sdlffcd_KeyMod;

typedef void (*sdlffcd_KeyCallback)(void* userdata, uint32_t key, uint16_t mod);

typedef enum sdlffcd_WindowEvent {
    SDLFFCD_WINDOW_EVENT_NONE = 0,
    SDLFFCD_WINDOW_EVENT_PIXEL_SIZE_CHANGED = 1,
    SDLFFCD_WINDOW_EVENT_DISPLAY_SCALE_CHANGED = 2
} sdlffcd_WindowEvent;

typedef void (*sdlffcd_WindowEventCallback)(void* userdata, sdlffcd_WindowEvent event);

/// Initialize SDL3, create window and renderer. Returns NULL on failure.
sdlffcd_AppContext* sdlffcd_app_init(const char* title, int width, int height);

/// Check if application is running.
bool sdlffcd_app_is_running(const sdlffcd_AppContext* app);

/// Request application to stop.
void sdlffcd_app_stop(sdlffcd_AppContext* app);

/// Register callback for key press events.
void sdlffcd_app_set_key_callback(sdlffcd_AppContext* app, sdlffcd_KeyCallback cb, void* userdata);

/// Register callback for window events (pixel size changed, display scale changed).
void sdlffcd_app_set_window_event_callback(sdlffcd_AppContext* app, sdlffcd_WindowEventCallback cb, void* userdata);

/// Poll and process all pending SDL events non-blocking.
void sdlffcd_app_poll_events(sdlffcd_AppContext* app);

/// Wait for next event with timeout in ms and process all queued events (timeout_ms < 0 waits indefinitely).
void sdlffcd_app_wait_events(sdlffcd_AppContext* app, int timeout_ms);

/// Wake main event loop by pushing custom registered SDL event.
bool sdlffcd_app_wake(sdlffcd_AppContext* app);

/// Clear screen and present frame
void sdlffcd_app_render(sdlffcd_AppContext* app);

/// Present current renderer frame.
void sdlffcd_app_present(sdlffcd_AppContext* app);

/// Destroy window/renderer and quit SDL3.
void sdlffcd_app_shutdown(sdlffcd_AppContext* app);

/// Check if window redraw is requested.
bool sdlffcd_app_need_redraw(const sdlffcd_AppContext* app);

/// Check if window redraw is requested, and clear the flag if set.
bool sdlffcd_app_check_and_clear_redraw(sdlffcd_AppContext* app);

/// Set or clear the window redraw requested flag.
void sdlffcd_app_set_need_redraw(sdlffcd_AppContext* app, bool need_redraw);

/// Get current window size in pixels/logical units. Returns false on invalid context or error.
bool sdlffcd_app_get_window_size(const sdlffcd_AppContext* app, int* out_w, int* out_h);

/// Get window display content scale factor (e.g. 1.0, 1.5, 2.0 for HiDPI).
float sdlffcd_app_get_display_scale(const sdlffcd_AppContext* app);

/// Toggle window fullscreen mode. Returns true on success.
bool sdlffcd_app_toggle_fullscreen(sdlffcd_AppContext* app);

/// Check if window is currently fullscreen.
bool sdlffcd_app_is_fullscreen(const sdlffcd_AppContext* app);

/* --- Video Renderer API --- */

typedef struct sdlffcd_VideoRenderer sdlffcd_VideoRenderer;

/// Create video renderer texture cache associated with application renderer.
sdlffcd_VideoRenderer* sdlffcd_video_renderer_create(sdlffcd_AppContext* app);

/// Render YUV420P planes (plane 0: Y, plane 1: U, plane 2: V) with letterboxing to application renderer.
bool sdlffcd_video_renderer_draw_yuv(sdlffcd_AppContext* app, sdlffcd_VideoRenderer* vr,
                                    const uint8_t* const data[8], const int linesize[8],
                                    int width, int height);

/// Redraw the last rendered video frame texture to current renderer viewport.
bool sdlffcd_video_renderer_redraw(sdlffcd_AppContext* app, sdlffcd_VideoRenderer* vr);

/// Destroy video renderer texture cache.
void sdlffcd_video_renderer_destroy(sdlffcd_VideoRenderer* vr);

/* --- Audio Stream Playback API --- */

typedef struct sdlffcd_AudioStream sdlffcd_AudioStream;

/// Open an SDL3 playback audio stream (standard 16-bit signed PCM). Returns NULL on failure.
sdlffcd_AudioStream* sdlffcd_audio_stream_open(int sample_rate, int channels);

/// Enqueue PCM audio data to the playback audio stream. Returns true on success.
bool sdlffcd_audio_stream_put_data(sdlffcd_AudioStream* stream, const void* data, int len);

/// Pause or resume audio playback stream. Returns true on success.
bool sdlffcd_audio_stream_set_paused(sdlffcd_AudioStream* stream, bool paused);

/// Check if audio playback stream is paused. Returns true if paused or invalid.
bool sdlffcd_audio_stream_is_paused(const sdlffcd_AudioStream* stream);

/// Clear all queued audio data in playback stream. Returns true on success.
bool sdlffcd_audio_stream_clear(sdlffcd_AudioStream* stream);

/// Set playback audio volume gain (1.0 = normal volume, 0.0 = muted). Returns true on success.
bool sdlffcd_audio_stream_set_volume(sdlffcd_AudioStream* stream, float volume);

/// Query current audio volume gain. Returns true on success.
bool sdlffcd_audio_stream_get_volume(const sdlffcd_AudioStream* stream, float* out_volume);

/// Close and destroy audio playback stream.
void sdlffcd_audio_stream_close(sdlffcd_AudioStream* stream);

/* --- Text & Font API --- */

typedef struct sdlffcd_Font sdlffcd_Font;
typedef struct sdlffcd_Text sdlffcd_Text;

/// Font hinting flags (matches TTF_HintingFlags values).
typedef enum sdlffcd_FontHinting {
    SDLFFCD_FONT_HINTING_NORMAL         = 0,
    SDLFFCD_FONT_HINTING_LIGHT          = 1,
    SDLFFCD_FONT_HINTING_MONO           = 2,
    SDLFFCD_FONT_HINTING_NONE           = 3,
    SDLFFCD_FONT_HINTING_LIGHT_SUBPIXEL = 4
} sdlffcd_FontHinting;

/// Open font from memory buffer at size in points. The memory buffer must remain valid for the lifetime of the font. Returns NULL on failure.
sdlffcd_Font* sdlffcd_font_open(const void* data, size_t data_size, float ptsize);

/// Set font hinting level.
bool sdlffcd_font_set_hinting(sdlffcd_Font* font, sdlffcd_FontHinting hinting);

/// Get current font hinting level.
sdlffcd_FontHinting sdlffcd_font_get_hinting(const sdlffcd_Font* font);

/// Set font point size and horizontal/vertical DPI.
bool sdlffcd_font_set_size_dpi(sdlffcd_Font* font, float ptsize, int hdpi, int vdpi);

/// Close font resource.
void sdlffcd_font_close(sdlffcd_Font* font);

/// Create reusable text object using app renderer text engine. Returns NULL on failure.
sdlffcd_Text* sdlffcd_text_create(sdlffcd_AppContext* app, sdlffcd_Font* font, const char* text);

/// Update string content of an existing text object, reusing memory and engine textures.
bool sdlffcd_text_set_string(sdlffcd_Text* text_obj, const char* new_text);

/// Set text ink RGBA color (0-255 range).
bool sdlffcd_text_set_color(sdlffcd_Text* text_obj, uint8_t r, uint8_t g, uint8_t b, uint8_t a);

/// Query text object size in pixels.
bool sdlffcd_text_get_size(const sdlffcd_Text* text_obj, int* out_w, int* out_h);

/// Render text object at (x, y) coordinates.
bool sdlffcd_text_draw(sdlffcd_Text* text_obj, float x, float y);

/// Render text object at (x, y) coordinates with a filled solid background rectangle.
bool sdlffcd_text_draw_with_bg(sdlffcd_AppContext* app, sdlffcd_Text* text_obj, float x, float y,
                               uint8_t bg_r, uint8_t bg_g, uint8_t bg_b, uint8_t bg_a, float padding);

/// Destroy text object and free associated resources.
void sdlffcd_text_destroy(sdlffcd_Text* text_obj);

/* --- Log API --- */

/// Log priority levels (matches SDL_LogPriority values).
typedef enum sdlffcd_LogPriority {
    SDLFFCD_LOG_PRIORITY_TRACE    = 1,
    SDLFFCD_LOG_PRIORITY_VERBOSE  = 2,
    SDLFFCD_LOG_PRIORITY_DEBUG    = 3,
    SDLFFCD_LOG_PRIORITY_INFO     = 4,
    SDLFFCD_LOG_PRIORITY_WARN     = 5,
    SDLFFCD_LOG_PRIORITY_ERROR    = 6,
    SDLFFCD_LOG_PRIORITY_CRITICAL = 7
} sdlffcd_LogPriority;

/// Log a pre-formatted message with specified category and priority.
/// Wraps SDL_LogMessage(category, priority, "%s", message).
void sdlffcd_log_message(int category, sdlffcd_LogPriority priority, const char* message);

/// Set priority threshold for all log categories.
void sdlffcd_log_set_all_priority(sdlffcd_LogPriority priority);
