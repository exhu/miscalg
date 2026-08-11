#pragma once
#include <stdbool.h>
#include <stdint.h>

typedef struct sdlffcd_AppContext sdlffcd_AppContext;

/// Initialize SDL3, create window and renderer. Returns NULL on failure.
sdlffcd_AppContext* sdlffcd_app_init(const char* title, int width, int height);

/// Check if application is running.
bool sdlffcd_app_is_running(const sdlffcd_AppContext* app);

/// Wait for next event and process all queued events (blocking when idle to save CPU).
void sdlffcd_app_wait_events(sdlffcd_AppContext* app);

/// Clear screen and present frame
void sdlffcd_app_render(sdlffcd_AppContext* app);

/// Destroy window/renderer and quit SDL3.
void sdlffcd_app_shutdown(sdlffcd_AppContext* app);

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
    int num_streams;
    int video_stream_index;  /* Selected video stream index in container, or -1 if none */
    int audio_stream_index;  /* Selected audio stream index in container, or -1 if none */
    int width;
    int height;
    double duration_seconds;
    double fps;
    int64_t num_frames;
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
    int linesize[8];     /* Pitch/stride for each plane in bytes */
    int width;
    int height;
    int pixel_format;
    double pts;          /* Presentation timestamp in seconds */
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

/// Close video context and free all allocated FFmpeg resources.
void sdlffcd_video_close(sdlffcd_VideoContext* vctx);

