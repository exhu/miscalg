module sdlffcd.video_player;

import std.logger : info, infof, error, errorf;
import std.string;
import std.datetime;
import core.thread;

import sdlffcd.sdlffcd_clib;
import sdlffcd.frame_ring_buffer;

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
    private enum defaultRingBufferCapacity = 8;

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
    private bool pausedSeekPending = false;

    this() {}

    ~this() {
        close();
    }

    bool open(string filename) {
        close();

        infof("VideoPlayer: Opening video file: %s", filename);
        vctx = sdlffcd_video_open(toStringz(filename));
        if (vctx is null) {
            errorf("VideoPlayer: Failed to open video file: %s", filename);
            return false;
        }

        if (sdlffcd_video_get_media_info(vctx, &mediaInfo)) {
            infof("Container format: %s", mediaInfo.format_name.ptr.fromStringz);
            infof("Video codec: %s", mediaInfo.video_codec_name.ptr.fromStringz);
            infof("Audio codec: %s", mediaInfo.audio_codec_name.ptr.fromStringz);
            infof("Resolution: %dx%d", mediaInfo.width, mediaInfo.height);
            infof("Duration: %.2f sec, FPS: %.2f, Frames: %d",
                mediaInfo.duration_seconds, mediaInfo.fps, mediaInfo.num_frames);
        }

        ringBuffer = new FrameRingBuffer(defaultRingBufferCapacity);
        decoderThread = new Thread(() => decodingWorker(vctx, ringBuffer));
        decoderThread.start();

        loaded = true;
        playbackStarted = false;
        paused = false;
        frameCount = 0;
        currentPts = 0.0;
        slotReady = false;
        pausedSeekPending = false;

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

    /// Check pending redraw flag and redraw current vctx surface if set.
    /// Returns true if a redraw was issued.
    private bool checkRedraw(sdlffcd_AppContext* app) {
        if (sdlffcd_app_check_and_clear_redraw(app)) {
            if (vctx !is null) {
                sdlffcd_video_redraw(app, vctx);
            }
            return true;
        }
        return false;
    }

    /// Return effective PTS, synthesising from frameCount when raw pts is negative.
    private double resolvePts(double rawPts) const {
        if (rawPts < 0.0 && mediaInfo.fps > 0) {
            return cast(double)frameCount / mediaInfo.fps;
        }
        return rawPts;
    }

    /// Return elapsed time in milliseconds since playback started.
    private long elapsedMs() const {
        return (MonoTime.currTime - playbackStartTime).total!"msecs"();
    }

    /**
     * Non-blocking update method. Call once per main event loop iteration.
     * Returns PlayerUpdateState: error, videoEnd, or updateAgain with next delay in milliseconds.
     */
    PlayerUpdateState update(sdlffcd_AppContext* app) {
        if (!loaded || app is null) return PlayerUpdateState.error();

        if (paused) return handlePaused(app);
        if (!slotReady) return handleBufferWait(app);
        return handlePlayback(app);
    }

    private PlayerUpdateState handlePaused(sdlffcd_AppContext* app) {
        if (pausedSeekPending) {
            if (!slotReady) {
                if (ringBuffer.pop(renderSlot)) {
                    slotReady = true;
                }
            }

            if (slotReady) {
                if (renderSlot.status == sdlffcd_DecodeStatus.SDLFFCD_DECODE_OK) {
                    frameCount = mediaInfo.fps > 0 ? cast(long)(renderSlot.frame.pts * mediaInfo.fps) : frameCount;
                    currentPts = resolvePts(renderSlot.frame.pts);
                    sdlffcd_video_render_frame(app, vctx, &renderSlot.frame);
                    slotReady = false;
                    pausedSeekPending = false;
                    return PlayerUpdateState.updateAgain(-1, true);
                } else {
                    slotReady = false;
                    pausedSeekPending = false;
                }
            }
            return PlayerUpdateState.updateAgain(1, checkRedraw(app));
        }

        bool reqRedraw = checkRedraw(app);
        return PlayerUpdateState.updateAgain(-1, reqRedraw);
    }

    private PlayerUpdateState handleBufferWait(sdlffcd_AppContext* app) {
        if (ringBuffer.pop(renderSlot)) {
            slotReady = true;
            return handlePlayback(app);
        } else {
            if (!decoderThread.isRunning) {
                return PlayerUpdateState.videoEnd();
            }
            bool reqRedraw = checkRedraw(app);
            return PlayerUpdateState.updateAgain(1, reqRedraw);
        }
    }

    private PlayerUpdateState handlePlayback(sdlffcd_AppContext* app) {
        if (renderSlot.status == sdlffcd_DecodeStatus.SDLFFCD_DECODE_EOF) {
            bool reqRedraw = checkRedraw(app);
            info("VideoPlayer: Reached end of video stream.");
            return PlayerUpdateState.videoEnd();
        }
        if (renderSlot.status != sdlffcd_DecodeStatus.SDLFFCD_DECODE_OK) {
            error("VideoPlayer: Error decoding frame.");
            return PlayerUpdateState.error();
        }

        if (!playbackStarted) {
            playbackStartTime = MonoTime.currTime;
            playbackStarted = true;
            if (vctx !is null) {
                sdlffcd_video_set_audio_paused(vctx, false);
            }
        }

        double framePts = resolvePts(renderSlot.frame.pts);
        long targetMs = cast(long)(framePts * 1000.0);
        long currElapsedMs = elapsedMs();

        if (currElapsedMs < targetMs) {
            long remainingMs = targetMs - currElapsedMs;
            if (remainingMs < 0) remainingMs = 0;
            bool reqRedraw = checkRedraw(app);
            return PlayerUpdateState.updateAgain(cast(int)remainingMs, reqRedraw);
        }

        // Render ready frame
        frameCount++;
        currentPts = framePts;
        sdlffcd_video_render_frame(app, vctx, &renderSlot.frame);
        slotReady = false;

        return preFetchNext(app);
    }

    private PlayerUpdateState preFetchNext(sdlffcd_AppContext* app) {
        // Pre-fetch next slot to compute wait timeout for next iteration
        if (ringBuffer.pop(renderSlot)) {
            slotReady = true;
            if (renderSlot.status == sdlffcd_DecodeStatus.SDLFFCD_DECODE_EOF ||
                renderSlot.status != sdlffcd_DecodeStatus.SDLFFCD_DECODE_OK) {
                // Pre-fetched slot is EOF/error; return immediately so next
                // update() loop iteration handles it without extra delay.
                return PlayerUpdateState.updateAgain(0, true);
            }

            double nextPts = resolvePts(renderSlot.frame.pts);
            long nextTargetMs = cast(long)(nextPts * 1000.0);
            long nextElapsedMs = elapsedMs();
            long waitMs = nextTargetMs - nextElapsedMs;
            if (waitMs < 0) waitMs = 0;
            return PlayerUpdateState.updateAgain(cast(int)waitMs, true);
        }

        return PlayerUpdateState.updateAgain(1, true);
    }

    void pause() {
        if (loaded && !paused) {
            paused = true;
            pausedSeekPending = false;
            pauseStartTime = MonoTime.currTime;
            if (vctx !is null) {
                sdlffcd_video_set_audio_paused(vctx, true);
            }
            infof("VideoPlayer: Paused at %.2f s", currentPts);
        }
    }

    void resume() {
        if (loaded && paused) {
            paused = false;
            pausedSeekPending = false;
            if (playbackStarted) {
                playbackStartTime += (MonoTime.currTime - pauseStartTime);
            }
            if (vctx !is null) {
                sdlffcd_video_set_audio_paused(vctx, false);
            }
            infof("VideoPlayer: Resumed at %.2f s", currentPts);
        }
    }

    void togglePause() {
        if (paused) resume();
        else pause();
    }

    @property bool isPaused() const {
        return paused;
    }

    @property bool isLoaded() const {
        return loaded;
    }

    double getDuration() const {
        return (loaded && mediaInfo.duration_seconds > 0.0) ? mediaInfo.duration_seconds : 0.0;
    }

    double getFps() const {
        return (loaded && mediaInfo.fps > 0.0) ? mediaInfo.fps : 0.0;
    }

    double getEndFrameTime() const {
        if (!loaded) return 0.0;
        double frameDuration = (mediaInfo.fps > 0.0) ? (1.0 / mediaInfo.fps) : 0.0;
        double endFrame = mediaInfo.duration_seconds - frameDuration;
        return (endFrame > 0.0) ? endFrame : 0.0;
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

        infof("VideoPlayer: Seeking to %.2f seconds", targetPts);
        currentPts = targetPts;
        if (vctx !is null) {
            sdlffcd_video_clear_audio(vctx);
        }
        ringBuffer.requestSeek(targetPts);
        slotReady = false;

        // Reset clock baseline so frame rendering syncs immediately
        playbackStartTime = MonoTime.currTime - dur!"msecs"(cast(long)(targetPts * 1000.0));
        if (paused) {
            pausedSeekPending = true;
            pauseStartTime = MonoTime.currTime;
        }
    }

    void rewind(double seconds = 5.0) {
        seekTo(currentPts - seconds);
    }

    void fastForward(double seconds = 5.0) {
        seekTo(currentPts + seconds);
    }

    void stepFrame(int direction) {
        if (!loaded) return;
        if (!paused) {
            pause();
        }
        double frameDuration = (mediaInfo.fps > 0.0) ? (1.0 / mediaInfo.fps) : (1.0 / 30.0);
        double target = currentPts + (direction * frameDuration);
        double endFrame = getEndFrameTime();
        if (target < 0.0) target = 0.0;
        if (target > endFrame) target = endFrame;
        seekTo(target);
    }

    bool redraw(sdlffcd_AppContext* app) {
        if (!loaded || app is null || vctx is null) return false;
        return sdlffcd_video_redraw(app, vctx);
    }

    @property bool hasAudio() const {
        return loaded && (vctx !is null) && sdlffcd_video_has_audio(vctx);
    }

    bool setVolume(float volume) {
        if (!loaded || vctx is null) return false;
        return sdlffcd_video_set_audio_volume(vctx, volume);
    }

    float getVolume() const {
        if (!loaded || vctx is null) return 0.0f;
        float vol = 1.0f;
        if (sdlffcd_video_get_audio_volume(vctx, &vol)) return vol;
        return 0.0f;
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

    auto player = new VideoPlayer();
    assert(!player.isLoaded);
    assert(!player.isPaused);
    assert(player.getEndFrameTime() == 0.0);
    assert(player.getFps() == 0.0);
    assert(!player.redraw(null));
    assert(!player.hasAudio);
    assert(!player.setVolume(0.5f));
    assert(player.getVolume() == 0.0f);
}
