module video_player;

import std.stdio;
import std.string;
import std.datetime;
import core.thread;

import sdlffcd_clib;
import frame_ring_buffer;

enum PlayerStatus {
    error,
    videoEnd,
    updateAgain
}

struct PlayerUpdateState {
    PlayerStatus status;
    int nextUpdateMs;
    bool frameRendered;

    @property bool isError() const { return status == PlayerStatus.error; }
    @property bool isVideoEnd() const { return status == PlayerStatus.videoEnd; }
    @property bool isUpdateAgain() const { return status == PlayerStatus.updateAgain; }

    static PlayerUpdateState updateAgain(int nextUpdateMs = 0, bool frameRendered = false) {
        return PlayerUpdateState(PlayerStatus.updateAgain, nextUpdateMs, frameRendered);
    }

    static PlayerUpdateState videoEnd() {
        return PlayerUpdateState(PlayerStatus.videoEnd, 0, false);
    }

    static PlayerUpdateState error() {
        return PlayerUpdateState(PlayerStatus.error, 0, false);
    }
}

/**
 * Non-blocking video player designed to run safely within a main event loop.
 * Does NOT call sdlffcd_app_poll_events or sdlffcd_app_wait_events.
 */
final class VideoPlayer {
    private sdlffcd_VideoContext* vctx;
    private sdlffcd_MediaInfo mediaInfo;
    private FrameRingBuffer ringBuffer;
    private Thread decoderThread;

    private bool loaded = false;
    private bool paused = false;
    private MonoTime pauseStartTime;

    private MonoTime playbackStartTime;
    private bool playbackStarted = false;
    private double currentPts = 0.0;
    private long frameCount = 0;

    private DecodedSlot renderSlot;
    private bool slotReady = false;

    this() {}

    ~this() {
        close();
    }

    bool open(string filename) {
        close();

        writeln("VideoPlayer: Opening video file: ", filename);
        vctx = sdlffcd_video_open(toStringz(filename));
        if (vctx is null) {
            stderr.writeln("VideoPlayer: Failed to open video file: ", filename);
            return false;
        }

        if (sdlffcd_video_get_media_info(vctx, &mediaInfo)) {
            writefln("Container format: %s", mediaInfo.format_name.ptr.fromStringz);
            writefln("Video codec: %s", mediaInfo.video_codec_name.ptr.fromStringz);
            writefln("Audio codec: %s", mediaInfo.audio_codec_name.ptr.fromStringz);
            writefln("Resolution: %dx%d", mediaInfo.width, mediaInfo.height);
            writefln("Duration: %.2f sec, FPS: %.2f, Frames: %d",
                mediaInfo.duration_seconds, mediaInfo.fps, mediaInfo.num_frames);
        }

        ringBuffer = new FrameRingBuffer(ringBufferCapacity);
        decoderThread = new Thread(() => decodingWorker(vctx, ringBuffer));
        decoderThread.start();

        loaded = true;
        playbackStarted = false;
        paused = false;
        frameCount = 0;
        currentPts = 0.0;
        slotReady = false;

        return true;
    }

    void close() {
        if (!loaded) return;
        loaded = false;

        if (ringBuffer !is null) {
            ringBuffer.requestStop();
        }
        if (decoderThread !is null) {
            decoderThread.join();
            decoderThread = null;
        }
        if (vctx !is null) {
            sdlffcd_video_close(vctx);
            vctx = null;
        }
    }

    static private void decodingWorker(sdlffcd_VideoContext* vctx, FrameRingBuffer ringBuffer) {
        long decodedCount = 0;
        while (!ringBuffer.isStopRequested()) {
            double seekTargetPts;
            if (ringBuffer.checkAndClearSeekRequest(seekTargetPts)) {
                sdlffcd_video_seek(vctx, seekTargetPts);
            }

            sdlffcd_VideoFrame frame;
            sdlffcd_DecodeStatus status = sdlffcd_video_decode_frame(vctx, &frame);
            decodedCount++;
            bool pushed = ringBuffer.push(status, frame, decodedCount);
            if (!pushed) {
                if (ringBuffer.isStopRequested()) break;
                continue;
            }
            if (status == sdlffcd_DecodeStatus.SDLFFCD_DECODE_ERROR) {
                break;
            }
        }
    }

    /**
     * Non-blocking update method. Call once per main event loop iteration.
     * Returns PlayerUpdateState: error, videoEnd, or updateAgain with next delay in milliseconds.
     */
    PlayerUpdateState update(sdlffcd_AppContext* app) {
        if (!loaded || app is null) return PlayerUpdateState.error();

        if (paused) {
            return PlayerUpdateState.updateAgain(-1);
        }

        if (!slotReady) {
            if (ringBuffer.pop(renderSlot)) {
                slotReady = true;
            } else {
                if (decoderThread !is null && !decoderThread.isRunning) {
                    return PlayerUpdateState.videoEnd();
                }
                return PlayerUpdateState.updateAgain(1);
            }
        }

        if (renderSlot.status == sdlffcd_DecodeStatus.SDLFFCD_DECODE_EOF) {
            writeln("VideoPlayer: Reached end of video stream.");
            return PlayerUpdateState.videoEnd();
        }
        if (renderSlot.status != sdlffcd_DecodeStatus.SDLFFCD_DECODE_OK) {
            stderr.writeln("VideoPlayer: Error decoding frame.");
            return PlayerUpdateState.error();
        }

        if (!playbackStarted) {
            playbackStartTime = MonoTime.currTime;
            playbackStarted = true;
        }

        double framePts = renderSlot.frame.pts;
        if (framePts < 0.0 && mediaInfo.fps > 0) {
            framePts = cast(double)frameCount / mediaInfo.fps;
        }

        long targetMs = cast(long)(framePts * 1000.0);
        long elapsedMs = (MonoTime.currTime - playbackStartTime).total!"msecs"();

        if (elapsedMs < targetMs) {
            long remainingMs = targetMs - elapsedMs;
            if (remainingMs < 0) remainingMs = 0;
            return PlayerUpdateState.updateAgain(cast(int)remainingMs);
        }

        // Render ready frame
        frameCount++;
        currentPts = framePts;
        sdlffcd_video_render_frame(app, vctx, &renderSlot.frame);
        slotReady = false;

        // Pre-fetch next slot to compute wait timeout for next iteration
        if (ringBuffer.pop(renderSlot)) {
            slotReady = true;
            if (renderSlot.status == sdlffcd_DecodeStatus.SDLFFCD_DECODE_EOF ||
                renderSlot.status != sdlffcd_DecodeStatus.SDLFFCD_DECODE_OK) {
                return PlayerUpdateState.updateAgain(0, true);
            }

            double nextPts = renderSlot.frame.pts;
            if (nextPts < 0.0 && mediaInfo.fps > 0) {
                nextPts = cast(double)frameCount / mediaInfo.fps;
            }
            long nextTargetMs = cast(long)(nextPts * 1000.0);
            long nextElapsedMs = (MonoTime.currTime - playbackStartTime).total!"msecs"();
            long waitMs = nextTargetMs - nextElapsedMs;
            if (waitMs < 0) waitMs = 0;
            return PlayerUpdateState.updateAgain(cast(int)waitMs, true);
        }

        return PlayerUpdateState.updateAgain(1, true);
    }

    void pause() {
        if (loaded && !paused) {
            paused = true;
            pauseStartTime = MonoTime.currTime;
            writefln("VideoPlayer: Paused at %.2f s", currentPts);
        }
    }

    void resume() {
        if (loaded && paused) {
            paused = false;
            if (playbackStarted) {
                playbackStartTime += (MonoTime.currTime - pauseStartTime);
            }
            writefln("VideoPlayer: Resumed at %.2f s", currentPts);
        }
    }

    void togglePause() {
        if (paused) resume();
        else pause();
    }

    bool isPaused() const {
        return paused;
    }

    bool isLoaded() const {
        return loaded;
    }

    double getDuration() const {
        return mediaInfo.duration_seconds;
    }

    double getCurrentPts() const {
        return currentPts;
    }

    void seekTo(double targetPts) {
        if (!loaded) return;
        if (targetPts < 0.0) targetPts = 0.0;
        if (mediaInfo.duration_seconds > 0 && targetPts > mediaInfo.duration_seconds) {
            targetPts = mediaInfo.duration_seconds;
        }

        writefln("VideoPlayer: Seeking to %.2f seconds", targetPts);
        ringBuffer.requestSeek(targetPts);
        slotReady = false;
        currentPts = targetPts;
        frameCount = mediaInfo.fps > 0 ? cast(long)(targetPts * mediaInfo.fps) : 0;

        // Reset clock baseline so frame rendering syncs immediately
        playbackStartTime = MonoTime.currTime - dur!"msecs"(cast(long)(targetPts * 1000.0));
        if (paused) {
            pauseStartTime = MonoTime.currTime;
        }
    }

    void rewind(double seconds = 5.0) {
        seekTo(currentPts - seconds);
    }

    void fastForward(double seconds = 5.0) {
        seekTo(currentPts + seconds);
    }
}

unittest {
    auto stateAgain = PlayerUpdateState.updateAgain(33);
    assert(stateAgain.isUpdateAgain);
    assert(!stateAgain.isError);
    assert(!stateAgain.isVideoEnd);
    assert(stateAgain.nextUpdateMs == 33);

    auto stateEnd = PlayerUpdateState.videoEnd();
    assert(stateEnd.isVideoEnd);
    assert(!stateEnd.isError);
    assert(!stateEnd.isUpdateAgain);

    auto stateErr = PlayerUpdateState.error();
    assert(stateErr.isError);
    assert(!stateErr.isVideoEnd);
    assert(!stateErr.isUpdateAgain);
}
