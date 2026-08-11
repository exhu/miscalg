import std.stdio;
import std.string;
import core.thread;
import std.datetime;
import sdlffcd_clib;
import frame_ring_buffer;

void decodingWorker(sdlffcd_VideoContext* vctx, FrameRingBuffer ringBuffer)
{
    long decodedCount = 0;
    while (!ringBuffer.isStopRequested())
    {
        sdlffcd_VideoFrame frame;
        sdlffcd_DecodeStatus status = sdlffcd_video_decode_frame(vctx, &frame);
        decodedCount++;
        bool pushed = ringBuffer.push(status, frame, decodedCount);
        if (!pushed || status != sdlffcd_DecodeStatus.SDLFFCD_DECODE_OK)
        {
            break;
        }
    }
}

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

        FrameRingBuffer ringBuffer = new FrameRingBuffer(ringBufferCapacity);
        Thread decoderThread = new Thread(() => decodingWorker(vctx, ringBuffer));
        decoderThread.start();
        scope(exit)
        {
            ringBuffer.requestStop();
            decoderThread.join();
        }

        writeln("\nDecoding and rendering video frames...");
        long frameCount = 0;
        MonoTime playbackStartTime;
        bool playbackStarted = false;
        DecodedSlot renderSlot;

        while (sdlffcd_app_is_running(app))
        {
            if (ringBuffer.pop(renderSlot))
            {
                if (renderSlot.status == sdlffcd_DecodeStatus.SDLFFCD_DECODE_OK)
                {
                    if (!playbackStarted)
                    {
                        playbackStartTime = MonoTime.currTime;
                        playbackStarted = true;
                    }

                    frameCount++;
                    // Log detailed metadata for the head (first 5) and tail (last 5) frames
                    if (frameCount <= headFrames || frameCount >= tailStartFrame)
                    {
                        writefln("Frame #%d: resolution %dx%d, pts %.3f s, plane0 ptr %s, linesize0 %d",
                            frameCount, renderSlot.frame.width, renderSlot.frame.height, renderSlot.frame.pts, renderSlot.frame.data[0], renderSlot.frame.linesize[0]);
                    }
                    // Log ellipsis once on frame 6 to indicate skipped intermediate frames
                    else if (frameCount == headFrames + 1)
                    {
                        writeln("...");
                    }

                    // Render video frame to SDL window using reused texture in vctx
                    sdlffcd_video_render_frame(app, vctx, &renderSlot.frame);

                    // Precise presentation timing using MonoTime and frame pts target
                    if (info.fps > 0)
                    {
                        double targetPts = (renderSlot.frame.pts > 0.0) ? renderSlot.frame.pts : (cast(double)(frameCount - 1) / info.fps);
                        long targetMs = cast(long)(targetPts * 1000.0);
                        long elapsedMs = (MonoTime.currTime - playbackStartTime).total!"msecs"();
                        long sleepMs = targetMs - elapsedMs;
                        if (sleepMs > 0)
                        {
                            Thread.sleep(dur!"msecs"(sleepMs));
                        }
                    }
                    else if (frameDelayMs > 0)
                    {
                        Thread.sleep(dur!"msecs"(frameDelayMs));
                    }
                }
                else if (renderSlot.status == sdlffcd_DecodeStatus.SDLFFCD_DECODE_EOF)
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
            else
            {
                // Ring buffer empty: sleep briefly to yield CPU while waiting for producer
                Thread.sleep(dur!"msecs"(1));
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

