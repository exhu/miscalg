extern(C):

struct sdlffcd_AppContext;

sdlffcd_AppContext* sdlffcd_app_init(const char* title, int width, int height);
bool sdlffcd_app_is_running(const sdlffcd_AppContext* app);
void sdlffcd_app_wait_events(sdlffcd_AppContext* app);
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
    int num_streams;
    int video_stream_index;
    int audio_stream_index;
    int width;
    int height;
    double duration_seconds;
    double fps;
    long num_frames;
    int pixel_format;
}

struct sdlffcd_VideoFrame {
    ubyte*[8] data;
    int[8] linesize;
    int width;
    int height;
    int pixel_format;
    double pts;
}

sdlffcd_VideoContext* sdlffcd_video_open(const char* filename);
bool sdlffcd_video_get_media_info(const sdlffcd_VideoContext* vctx, sdlffcd_MediaInfo* out_info);
sdlffcd_DecodeStatus sdlffcd_video_decode_frame(sdlffcd_VideoContext* vctx, sdlffcd_VideoFrame* out_frame);
void sdlffcd_video_close(sdlffcd_VideoContext* vctx);
