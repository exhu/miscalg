import std.stdio;
import std.string;
import core.thread;
import std.datetime;
import sdlffcd_clib;

void decode_video_file(sdlffcd_AppContext* app, string filename)
{
        writeln("Opening video file: ", filename);
        sdlffcd_VideoContext* vctx = sdlffcd_video_open(toStringz(filename));
        if (vctx is null)
        {
            stderr.writeln("Failed to open video file: ", filename);
            return;
        }
        scope(exit) sdlffcd_video_close(vctx);

        sdlffcd_MediaInfo info;
        if (sdlffcd_video_get_media_info(vctx, &info))
        {
            writefln("Container format: %s", info.format_name.ptr.fromStringz);
            writefln("Video codec: %s", info.video_codec_name.ptr.fromStringz);
            writefln("Audio codec: %s", info.audio_codec_name.ptr.fromStringz);
            writefln("Streams count: %d (Video idx: %d, Audio idx: %d)",
                info.num_streams, info.video_stream_index, info.audio_stream_index);
            writefln("Resolution: %dx%d", info.width, info.height);
            writefln("Duration: %.2f sec, FPS: %.2f, Frames: %d",
                info.duration_seconds, info.fps, info.num_frames);
        }

        // Log output window settings: show initial headFrames (5) and final tailFrames (5)
        enum headFrames = 5;
        enum tailFrames = 5;

        // Calculate starting frame index for tail logging based on total video frame count.
        const long tailStartFrame = (info.num_frames > (headFrames + tailFrames))
            ? (info.num_frames - tailFrames + 1)
            : (info.num_frames > 0 ? (headFrames + 1) : long.max);

        long frameDelayMs = (info.fps > 0) ? cast(long)(1000.0 / info.fps) : 33;

        writeln("\nDecoding and rendering video frames...");
        sdlffcd_VideoFrame frame;
        long frameCount = 0;
        while (sdlffcd_app_is_running(app))
        {
            sdlffcd_DecodeStatus status = sdlffcd_video_decode_frame(vctx, &frame);
            if (status == sdlffcd_DecodeStatus.SDLFFCD_DECODE_OK)
            {
                frameCount++;
                // Log detailed metadata for the head (first 5) and tail (last 5) frames
                if (frameCount <= headFrames || frameCount >= tailStartFrame)
                {
                    writefln("Frame #%d: resolution %dx%d, pts %.3f s, plane0 ptr %s, linesize0 %d",
                        frameCount, frame.width, frame.height, frame.pts, frame.data[0], frame.linesize[0]);
                }
                // Log ellipsis once on frame 6 to indicate skipped intermediate frames
                else if (frameCount == headFrames + 1)
                {
                    writeln("...");
                }

                // Render video frame to SDL window using reused texture in vctx
                sdlffcd_video_render_frame(app, vctx, &frame);

                // Frame rate timing and event handling
                if (frameDelayMs > 0)
                {
                    Thread.sleep(dur!"msecs"(frameDelayMs));
                }
            }
            else if (status == sdlffcd_DecodeStatus.SDLFFCD_DECODE_EOF)
            {
                writefln("End of video stream reached cleanly after %d frames.", frameCount);
                break;
            }
            else
            {
                stderr.writeln("Error decoding frame.");
                break;
            }
        }
}

void main(string[] args)
{
    string filename = (args.length > 1) ? args[1] : "samplevideo.mp4";

    writeln("Initializing SDL application...");
    sdlffcd_AppContext* app = sdlffcd_app_init("sdlffcd - Video Player", 800, 600);
    if (app is null)
    {
        stderr.writeln("Failed to initialize application context.");
        return;
    }
    scope(exit) sdlffcd_app_shutdown(app);

    // Test waking event loop via custom registered SDL event
    if (sdlffcd_app_wake(app))
    {
        writeln("Custom wake event successfully sent to event loop.");
        sdlffcd_app_wait_events(app);
    }
    decode_video_file(app, filename);

    writeln("Exited cleanly.");
}

