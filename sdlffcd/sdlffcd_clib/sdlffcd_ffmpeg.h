#pragma once
#include <stdbool.h>
#include <stdint.h>

/* --- FFmpeg Video & Audio Decoding API --- */

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
    int audio_sample_rate;
    int audio_channels;
} sdlffcd_MediaInfo;

/**
 * Decoded video frame plane pointers and metadata.
 * Note: plane data pointers shallowly reference internal FFmpeg frame buffers managed
 * by the video context. Data pointers remain valid until next decode_frame or video_close.
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

/// Callback for delivered resampled 16-bit signed stereo PCM audio data.
typedef void (*sdlffcd_AudioDataCallback)(void* userdata, const uint8_t* pcm_data, int byte_len);

/// Open a video file and initialize FFmpeg demuxer and decoder contexts. Returns NULL on failure.
sdlffcd_VideoContext* sdlffcd_video_open(const char* filename);

/// Retrieve media info from an open video context into out_info. Returns false if context/out_info is NULL.
bool sdlffcd_video_get_media_info(const sdlffcd_VideoContext* vctx, sdlffcd_MediaInfo* out_info);

/// Set callback for receiving resampled PCM audio data packets during decoding.
/// NOTE! the callback is called from the thread where sdlffcd_video_decode_frame is called.
void sdlffcd_video_set_audio_callback(sdlffcd_VideoContext* vctx, sdlffcd_AudioDataCallback cb, void* userdata);

/**
 * Decode next frame from video file context.
 *
 * @param vctx Pointer to opened video context.
 * @param out_frame Pointer to caller-allocated sdlffcd_VideoFrame structure to populate.
 * @return SDLFFCD_DECODE_OK (0) on success, SDLFFCD_DECODE_EOF (1) when end of file/stream is reached,
 *         or SDLFFCD_DECODE_ERROR (-1) on decoding failure.
 */
sdlffcd_DecodeStatus sdlffcd_video_decode_frame(sdlffcd_VideoContext* vctx, sdlffcd_VideoFrame* out_frame);

/// Seek to target timestamp in seconds.
bool sdlffcd_video_seek(sdlffcd_VideoContext* vctx, double target_pts_seconds);

/// Check if video context has an active audio stream and decoder.
bool sdlffcd_video_has_audio(const sdlffcd_VideoContext* vctx);

/// Close video context and free all allocated FFmpeg and audio resampling resources.
void sdlffcd_video_close(sdlffcd_VideoContext* vctx);
