#pragma once
#include <stdbool.h>
#include <stdint.h>

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

/// Initialize SDL3, create window and renderer. Returns NULL on failure.
sdlffcd_AppContext* sdlffcd_app_init(const char* title, int width, int height);

/// Check if application is running.
bool sdlffcd_app_is_running(const sdlffcd_AppContext* app);

/// Request application to stop.
void sdlffcd_app_stop(sdlffcd_AppContext* app);

/// Register callback for key press events.
void sdlffcd_app_set_key_callback(sdlffcd_AppContext* app, sdlffcd_KeyCallback cb, void* userdata);

/// Poll and process all pending SDL events non-blocking.
void sdlffcd_app_poll_events(sdlffcd_AppContext* app);

/// Wait for next event with timeout in ms and process all queued events (timeout_ms < 0 waits indefinitely).
void sdlffcd_app_wait_events(sdlffcd_AppContext* app, int timeout_ms);

/// Wake main event loop by pushing custom registered SDL event.
bool sdlffcd_app_wake(sdlffcd_AppContext* app);

/// Clear screen and present frame
void sdlffcd_app_render(sdlffcd_AppContext* app);

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

/// Toggle window fullscreen mode. Returns true on success.
bool sdlffcd_app_toggle_fullscreen(sdlffcd_AppContext* app);

/// Check if window is currently fullscreen.
bool sdlffcd_app_is_fullscreen(const sdlffcd_AppContext* app);

/* --- Video API --- */

typedef struct sdlffcd_VideoContext sdlffcd_VideoContext;

typedef enum sdlffcd_DecodeStatus {
    SDLFFCD_DECODE_ERROR = -1,
    SDLFFCD_DECODE_OK = 0,
    SDLFFCD_DECODE_EOF = 1
} sdlffcd_DecodeStatus;

typedef struct sdlffcd_MediaInfo {
    char format_name[64];
    char video_codec_name[64];
    char audio_codec_name[64];
    double duration_seconds;
    double fps;
    int64_t num_frames;
    int num_streams;
    int video_stream_index;  /* Selected video stream index in container, or -1 if none */
    int audio_stream_index;  /* Selected audio stream index in container, or -1 if none */
    int width;
    int height;
    int pixel_format;
} sdlffcd_MediaInfo;

/**
 * Decoded video frame plane pointers and metadata.
 * Note: plane data pointers shallowly reference internal FFmpeg frame buffers managed
 * by the video context. No memory is reallocated per call; data pointers remain valid
 * until the next call to sdlffcd_video_decode_frame or sdlffcd_video_close.
 */
typedef struct sdlffcd_VideoFrame {
    uint8_t* data[8];    /* Shallow pointers to decoded image planes in FFmpeg internal buffer */
    double pts;          /* Presentation timestamp in seconds */
    int linesize[8];     /* Pitch/stride for each plane in bytes */
    int width;
    int height;
    int pixel_format;
    uint8_t _pad[4];     /* Explicit padding to 8-byte alignment boundary */
} sdlffcd_VideoFrame;

/// Open a video file and initialize FFmpeg demuxer and decoder contexts. Returns NULL on failure.
sdlffcd_VideoContext* sdlffcd_video_open(const char* filename);

/// Retrieve media info from an open video context into out_info. Returns false if context/out_info is NULL.
bool sdlffcd_video_get_media_info(const sdlffcd_VideoContext* vctx, sdlffcd_MediaInfo* out_info);

/**
 * Decode next frame from video file context.
 *
 * @param vctx Pointer to opened video context.
 * @param out_frame Pointer to caller-allocated sdlffcd_VideoFrame structure to populate.
 * @return SDLFFCD_DECODE_OK (0) on success, SDLFFCD_DECODE_EOF (1) when end of file/stream is reached,
 *         or SDLFFCD_DECODE_ERROR (-1) on decoding failure.
 */
sdlffcd_DecodeStatus sdlffcd_video_decode_frame(sdlffcd_VideoContext* vctx, sdlffcd_VideoFrame* out_frame);
bool sdlffcd_video_seek(sdlffcd_VideoContext* vctx, double target_pts_seconds);
/**
 * Render a decoded video frame to the SDL renderer using the cached texture stored in vctx.
 *
 * Pointer lifetime semantics:
 * - `app` and `vctx` must remain valid, initialized context pointers for the duration of the call.
 * - `frame` and its plane data pointers (`frame->data`) reference frame buffer memory managed by `vctx`.
 *   The `frame` struct and data pointers are only guaranteed valid until the next call to `sdlffcd_video_decode_frame`
 *   or `sdlffcd_video_close`. `sdlffcd_video_render_frame` does not retain `frame` pointer references after returning.
 * - The internal `SDL_Texture` pointer is owned and managed by `vctx` and freed during `sdlffcd_video_close`.
 *
 * @param app Pointer to initialized sdlffcd_AppContext.
 * @param vctx Pointer to opened sdlffcd_VideoContext.
 * @param frame Pointer to decoded sdlffcd_VideoFrame to render.
 * @return true on successful render, false on error.
 */
bool sdlffcd_video_render_frame(sdlffcd_AppContext* app, sdlffcd_VideoContext* vctx, const sdlffcd_VideoFrame* frame);

/// Redraw the last rendered video frame texture to the current renderer viewport.
bool sdlffcd_video_redraw(sdlffcd_AppContext* app, sdlffcd_VideoContext* vctx);

/// Close video context and free all allocated FFmpeg resources.
void sdlffcd_video_close(sdlffcd_VideoContext* vctx);

/* --- Text API --- */

typedef struct sdlffcd_Font sdlffcd_Font;
typedef struct sdlffcd_Text sdlffcd_Text;

/// Present current renderer frame.
void sdlffcd_app_present(sdlffcd_AppContext* app);

/// Open font from file path at size in points. Returns NULL on failure.
sdlffcd_Font* sdlffcd_font_open(const char* filepath, float ptsize);

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
bool sdlffcd_text_draw_with_bg(sdlffcd_AppContext* app, sdlffcd_Text* text_obj, float x, float y, uint8_t bg_r, uint8_t bg_g, uint8_t bg_b, uint8_t bg_a, float padding);

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

