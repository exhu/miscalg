extern(C):

struct sdlffcd_AppContext;

enum sdlffcd_Key : uint {
    SDLFFCD_KEY_UNKNOWN = 0,
    SDLFFCD_KEY_ESCAPE = 27,
    SDLFFCD_KEY_Q = 'q'
}

alias sdlffcd_KeyCallback = void function(void* userdata, uint key);

sdlffcd_AppContext* sdlffcd_app_init(const char* title, int width, int height);
bool sdlffcd_app_is_running(const sdlffcd_AppContext* app);
void sdlffcd_app_stop(sdlffcd_AppContext* app);
void sdlffcd_app_set_key_callback(sdlffcd_AppContext* app, sdlffcd_KeyCallback cb, void* userdata);
void sdlffcd_app_poll_events(sdlffcd_AppContext* app);
void sdlffcd_app_wait_events(sdlffcd_AppContext* app);
bool sdlffcd_app_wake(sdlffcd_AppContext* app);
void sdlffcd_app_render(sdlffcd_AppContext* app);
void sdlffcd_app_shutdown(sdlffcd_AppContext* app);

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
bool sdlffcd_video_render_frame(sdlffcd_AppContext* app, sdlffcd_VideoContext* vctx, const(sdlffcd_VideoFrame)* frame);
void sdlffcd_video_close(sdlffcd_VideoContext* vctx);

