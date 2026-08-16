module sdlffcd.sdlffcd_ffmpeg;
extern(C):

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
    int audio_sample_rate;
    int audio_channels;
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

alias sdlffcd_AudioDataCallback = void function(void* userdata, const(ubyte)* pcm_data, int byte_len);

sdlffcd_VideoContext* sdlffcd_video_open(const char* filename);
bool sdlffcd_video_get_media_info(const(sdlffcd_VideoContext)* vctx, sdlffcd_MediaInfo* out_info);
void sdlffcd_video_set_audio_callback(sdlffcd_VideoContext* vctx, sdlffcd_AudioDataCallback cb, void* userdata);
sdlffcd_DecodeStatus sdlffcd_video_decode_frame(sdlffcd_VideoContext* vctx, sdlffcd_VideoFrame* out_frame);
bool sdlffcd_video_seek(sdlffcd_VideoContext* vctx, double target_pts_seconds);
bool sdlffcd_video_has_audio(const(sdlffcd_VideoContext)* vctx);
void sdlffcd_video_close(sdlffcd_VideoContext* vctx);

extern(D) unittest
{
    assert(sdlffcd_DecodeStatus.SDLFFCD_DECODE_ERROR == -1);
    assert(sdlffcd_DecodeStatus.SDLFFCD_DECODE_OK == 0);
    assert(sdlffcd_DecodeStatus.SDLFFCD_DECODE_EOF == 1);

    assert(sdlffcd_MediaInfo.sizeof == 248);
    assert(sdlffcd_VideoFrame.sizeof == 120);

    assert(sdlffcd_video_open(null) is null);
    assert(!sdlffcd_video_get_media_info(null, null));
    sdlffcd_video_set_audio_callback(null, null, null);
    sdlffcd_VideoFrame frame;
    assert(sdlffcd_video_decode_frame(null, &frame) == sdlffcd_DecodeStatus.SDLFFCD_DECODE_ERROR);
    assert(!sdlffcd_video_seek(null, 0.0));
    assert(!sdlffcd_video_has_audio(null));
    sdlffcd_video_close(null);
}
