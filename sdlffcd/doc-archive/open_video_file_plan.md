# Plan: Open Video File, Retrieve Media Info, and Decode Frame in sdlffcd_clib and D

## Goal Description
Implement public C functions in `sdlffcd_clib` and corresponding D bindings in `source/sdlffcd_clib.d` to:
1. Open a video file and initialize an opaque `sdlffcd_VideoContext` structure holding FFmpeg (`avformat`, `avcodec`, `avutil`) states.
2. Retrieve comprehensive media info (`sdlffcd_MediaInfo`) including container format, video/audio codec names, stream indices/counts, duration, FPS, and video resolution.
3. Decode video frames (`sdlffcd_VideoFrame`) returning plane data pointers, linesizes, PTS (presentation timestamp), and resolution.
4. Cleanly free all allocated FFmpeg contexts, frames, and packets on `sdlffcd_video_close`.
5. Expose and demonstrate these functions in D (`source/app.d`).

---

## Architecture Overview

```mermaid
flowchart TD
    subgraph D Application
        A["source/app.d (main)"] -->|"Calls video API"| B["source/sdlffcd_clib.d (extern C)"]
    end
    subgraph C Bridge Library (sdlffcd_clib)
        B -->|"C ABI"| C["sdlffcd_clib.h / sdlffcd_clib.c"]
        C -->|"Manages"| D["sdlffcd_VideoContext (fmt_ctx, codec_ctx, frame, pkt)"]
        C -->|"FFmpeg APIs"| E["libavformat / libavcodec / libavutil"]
    end
```

---

## User Review Required

> [!NOTE]
> All public C structs and functions will follow the project-wide `sdlffcd_` naming prefix convention.

> [!IMPORTANT]
> `sdlffcd_VideoContext` is defined as an opaque structure in `sdlffcd_clib.h` and `source/sdlffcd_clib.d`, concealing internal FFmpeg structures (`AVFormatContext`, `AVCodecContext`, `AVFrame`, `AVPacket`) from D code.

### Answers & Refinements from Feedback

1. **Frame Data Memory Allocation & Doc Comment**:
   - Added explicit doc comments to `sdlffcd_VideoFrame` explaining that plane data pointers shallowly reference FFmpeg internal frame buffers managed by `sdlffcd_VideoContext`. No heap reallocation occurs per call.
2. **Explicit `sdlffcd_DecodeStatus` Enum**:
   - Replaced `int` return type with `typedef enum sdlffcd_DecodeStatus` containing `SDLFFCD_DECODE_OK = 0`, `SDLFFCD_DECODE_EOF = 1`, and `SDLFFCD_DECODE_ERROR = -1`.
3. **Function Header Doc Comment**:
   - Added Doxygen/Javadoc-style comment to `sdlffcd_video_decode_frame` in `sdlffcd_clib.h`.

---

## Proposed Changes

### Component: C Bridge (`sdlffcd_clib`)

#### [MODIFY] [`sdlffcd_clib/sdlffcd_clib.h`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.h)
Add declarations for `sdlffcd_VideoContext`, `sdlffcd_MediaInfo`, `sdlffcd_VideoFrame`, `sdlffcd_DecodeStatus`, and public video functions:

```c
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

sdlffcd_VideoContext* sdlffcd_video_open(const char* filename);
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

void sdlffcd_video_close(sdlffcd_VideoContext* vctx);
```

#### [MODIFY] [`sdlffcd_clib/sdlffcd_clib_private.h`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib_private.h)
Include FFmpeg headers (`libavformat/avformat.h`, `libavcodec/avcodec.h`, `libavutil/avutil.h`) and define `struct sdlffcd_VideoContext`:

```c
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>

struct sdlffcd_VideoContext {
    AVFormatContext* fmt_ctx;
    AVCodecContext* video_codec_ctx;
    AVCodecContext* audio_codec_ctx;
    int video_stream_idx;
    int audio_stream_idx;
    AVFrame* frame;
    AVPacket* pkt;
    sdlffcd_MediaInfo info;
};
```

#### [MODIFY] [`sdlffcd_clib/sdlffcd_clib.c`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.c)
Implement video context lifecycle and decoding:
- `sdlffcd_video_open`: Opens input file with `avformat_open_input`, locates best video/audio streams via `av_find_best_stream`, allocates decoder contexts with `avcodec_open2`, allocates reusable `AVFrame` and `AVPacket`, populates `MediaInfo`.
- `sdlffcd_video_get_media_info`: Copies prefilled `sdlffcd_MediaInfo`.
- `sdlffcd_video_decode_frame`: Reads packets via `av_read_frame`, feeds `video_codec_ctx` via `avcodec_send_packet`, receives decoded frame via `avcodec_receive_frame`, populates `sdlffcd_VideoFrame` plane pointers. Returns `SDLFFCD_DECODE_OK` on frame decoded, `SDLFFCD_DECODE_EOF` on EOF, `SDLFFCD_DECODE_ERROR` on error.
- `sdlffcd_video_close`: Frees decoder contexts, frame, packet, format context, and context struct.

---

### Component: D Bindings & Application (`source`)

#### [MODIFY] [`source/sdlffcd_clib.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/sdlffcd_clib.d)
Expose exact matching D declarations for video structs, enum, and functions:

```d
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
```

#### [MODIFY] [`source/app.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/app.d)
Update `main` in `app.d` to accept a video filename argument (or test file), open video context, print media information (format, codecs, resolution, duration, FPS), decode sample frames, and close context.

---

## Verification Plan

### Automated Build Verification
1. Compile with D compiler and Meson build script:
   ```bash
   export PKG_CONFIG_PATH="$HOME/.local/lib/pkgconfig:$PKG_CONFIG_PATH" && dub build
   ```

### Functional & Manual Verification
1. Create a test video using `ffmpeg`:
   ```bash
   ffmpeg -y -f lavfi -i testsrc=duration=3:size=640x480:rate=30 -c:v libx264 test_input.mp4
   ```
2. Run `dub run -- test_input.mp4` and verify output:
   - Media info accurately reports `format_name`, `video_codec_name` (`h264`), `width` (`640`), `height` (`480`), `duration_seconds` (`~3.0`), `fps` (`30.0`).
   - Frame decoding successfully receives video frames with valid non-null plane pointers and increasing PTS values.
   - Clean shutdown with no memory leaks or crashes on `sdlffcd_video_close`.
