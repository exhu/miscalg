import std.stdio;
import std.string;
import sdlffcd_clib;

void decode_video_file(string filename)
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

        writeln("\nDecoding video frames...");
        sdlffcd_VideoFrame frame;
        int frameCount = 0;
        while (true)
        {
            sdlffcd_DecodeStatus status = sdlffcd_video_decode_frame(vctx, &frame);
            if (status == sdlffcd_DecodeStatus.SDLFFCD_DECODE_OK)
            {
                frameCount++;
                if (frameCount <= 5 || frameCount >= 86)
                {
                    writefln("Frame #%d: resolution %dx%d, pts %.3f s, plane0 ptr %s, linesize0 %d",
                        frameCount, frame.width, frame.height, frame.pts, frame.data[0], frame.linesize[0]);
                }
                else if (frameCount == 6)
                {
                    writeln("...");
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
    if (args.length > 1)
    {
        string filename = args[1];
        decode_video_file(filename);
        return;
    }

    writeln("Initializing SDL application...");
    sdlffcd_AppContext* app = sdlffcd_app_init("sdlffcd - Video Play&Trim", 800, 600);
    if (app is null)
    {
        stderr.writeln("Failed to initialize application context.");
        return;
    }

    // Initial frame render
    sdlffcd_app_render(app);

    writeln("Entering main loop (waiting for events)...");
    while (sdlffcd_app_is_running(app))
    {
        sdlffcd_app_wait_events(app);
        sdlffcd_app_render(app);
    }

    writeln("Shutting down application...");
    sdlffcd_app_shutdown(app);
    writeln("Exited cleanly.");
}
