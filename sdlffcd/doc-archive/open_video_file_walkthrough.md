# Walkthrough: Open Video File, Media Info Query, and Frame Decoding

Implemented video file opening, media info retrieval, frame decoding, and context cleanup in `sdlffcd_clib` with matching D declarations in `source/sdlffcd_clib.d` and demonstration in `source/app.d`.

## Changes Made

### C Bridge Library (`sdlffcd_clib`)

#### [`sdlffcd_clib/sdlffcd_clib.h`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.h)
- Added `sdlffcd_VideoContext` opaque struct declaration.
- Added `sdlffcd_DecodeStatus` enum (`SDLFFCD_DECODE_OK`, `SDLFFCD_DECODE_EOF`, `SDLFFCD_DECODE_ERROR`).
- Added `sdlffcd_MediaInfo` and `sdlffcd_VideoFrame` structures.
- Added public function prototypes with doc comments: `sdlffcd_video_open`, `sdlffcd_video_get_media_info`, `sdlffcd_video_decode_frame`, and `sdlffcd_video_close`.

#### [`sdlffcd_clib/sdlffcd_clib_private.h`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib_private.h)
- Included FFmpeg headers (`<libavformat/avformat.h>`, `<libavcodec/avcodec.h>`, `<libavutil/avutil.h>`).
- Defined `struct sdlffcd_VideoContext` containing demuxer/decoder contexts, stream indices, reusable frame & packet objects, and pre-populated media info.

#### [`sdlffcd_clib/sdlffcd_clib.c`](file:///home/yur/agy-projects/miscalg/sdlffcd/sdlffcd_clib/sdlffcd_clib.c)
- Implemented `sdlffcd_video_open`: Opens input file via `avformat_open_input`, locates best video/audio streams via `av_find_best_stream`, initializes video codec context, allocates reusable `AVFrame`/`AVPacket`, populates format/codec/resolution/duration/FPS/frame count.
- Implemented `sdlffcd_video_get_media_info`: Copies prefilled `sdlffcd_MediaInfo`.
- Implemented `sdlffcd_video_decode_frame`: Manages `avcodec_receive_frame` / `av_read_frame` packet decoding loop and returns `sdlffcd_DecodeStatus`.
- Implemented `sdlffcd_video_close`: Frees all FFmpeg resources cleanly.

### D Bindings & Application (`source`)

#### [`source/sdlffcd_clib.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/sdlffcd_clib.d)
- Added matching `extern(C)` declarations for `sdlffcd_VideoContext`, `sdlffcd_DecodeStatus`, `sdlffcd_MediaInfo`, `sdlffcd_VideoFrame`, and video C functions.

#### [`source/app.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/app.d)
- Updated `main(string[] args)` to accept a video filename argument, open the file, query media info, decode frames in a loop, and cleanly close the context.

---

## Verification Results

### Automated Build
Executed `export PKG_CONFIG_PATH="$HOME/.local/lib/pkgconfig:$PKG_CONFIG_PATH" && dub build`.
- Meson static library `libsdlffcd_clib.a` built cleanly.
- D compiler linked `sdlffcd` binary with 0 errors.

### Manual Verification
1. Created synthetic H.264 MP4 test video `test_input.mp4` (640x480, 30fps, 3 seconds / 90 frames).
2. Executed `./sdlffcd test_input.mp4`.
3. Verified stdout output:
   ```text
   Opening video file: test_input.mp4
   Container format: mov,mp4,m4a,3gp,3g2,mj2
   Video codec: h264
   Audio codec: none
   Streams count: 1 (Video idx: 0, Audio idx: -1)
   Resolution: 640x480
   Duration: 3.00 sec, FPS: 30.00, Frames: 90

   Decoding video frames...
   Frame #1: resolution 640x480, pts 0.000 s, plane0 ptr 651919B2A840, linesize0 640
   Frame #2: resolution 640x480, pts 0.033 s, plane0 ptr 651919E2CE00, linesize0 640
   ...
   Frame #90: resolution 640x480, pts 2.967 s, plane0 ptr 651919E2CE00, linesize0 640
   End of video stream reached cleanly after 90 frames.
   ```
