module frame_ring_buffer;

import core.sync.mutex;
import core.sync.condition;
import std.algorithm.mutation : swap;
import sdlffcd_clib;

/// Default capacity for shared decoded frame ring buffer (D camelCase convention)
enum ringBufferCapacity = 8;

/**
 * Slot in ring buffer holding a decoded video frame and its plane data.
 */
struct DecodedSlot {
    sdlffcd_VideoFrame frame;

    /**
     * Internal plane byte storage for frame data planes (plane 0..7).
     *
     * Memory allocation & reuse semantics:
     * - `planeBuffers[i]` arrays are allocated or resized on demand whenever `length < planeSize`
     *   (e.g. on initial frame push or if stream resolution changes).
     * - For subsequent frames with identical dimensions, the existing slice capacity is reused
     *   without reallocating D garbage-collected memory, avoiding per-frame GC allocations.
     */
    ubyte[][8] planeBuffers;

    sdlffcd_DecodeStatus status;
    long frameIndex;
}

/**
 * Thread-safe ring buffer for transferring decoded video frames from producer thread to main render loop.
 */
final class FrameRingBuffer {
    private DecodedSlot[] slots;
    private size_t capacity;
    private size_t head = 0;
    private size_t tail = 0;
    private size_t count = 0;
    private bool stopRequested = false;
    private Mutex mutex;
    private Condition notFull;
    private Condition notEmpty;

    this(size_t capacity = ringBufferCapacity) {
        this.capacity = capacity;
        this.slots = new DecodedSlot[capacity];
        this.mutex = new Mutex();
        this.notFull = new Condition(mutex);
        this.notEmpty = new Condition(mutex);
    }

    /**
     * Push a decoded frame into the ring buffer.
     * Blocks if buffer is full until space becomes available or stop is requested.
     */
    bool push(sdlffcd_DecodeStatus status, ref sdlffcd_VideoFrame srcFrame, long frameIdx) {
        synchronized (mutex) {
            while (count == capacity && !stopRequested) {
                notFull.wait();
            }

            if (stopRequested) return false;

            DecodedSlot* slot = &slots[head];
            slot.status = status;
            slot.frameIndex = frameIdx;
            slot.frame = srcFrame;

            if (status == sdlffcd_DecodeStatus.SDLFFCD_DECODE_OK) {
                for (int i = 0; i < 8; i++) {
                    if (srcFrame.data[i] !is null && srcFrame.linesize[i] > 0) {
                        size_t planeHeight = (i == 1 || i == 2) ? (srcFrame.height + 1) / 2 : srcFrame.height;
                        size_t planeSize = cast(size_t)planeHeight * srcFrame.linesize[i];

                        /* Reallocate plane buffer only if length is insufficient for frame dimensions;
                         * otherwise reuse existing allocated slice memory without GC allocation. */
                        if (slot.planeBuffers[i].length < planeSize) {
                            slot.planeBuffers[i].length = planeSize;
                        }
                        slot.planeBuffers[i][0 .. planeSize] = srcFrame.data[i][0 .. planeSize];
                        slot.frame.data[i] = slot.planeBuffers[i].ptr;
                    } else {
                        slot.frame.data[i] = null;
                    }
                }
            }

            head = (head + 1) % capacity;
            count++;
            notEmpty.notify();
            return true;
        }
    }

    /**
     * Try popping next decoded frame slot from ring buffer.
     * Swaps planeBuffers with outSlot to guarantee consumer frame memory ownership during rendering.
     * Returns true if slot was retrieved, or false if buffer is currently empty.
     */
    bool pop(ref DecodedSlot outSlot) {
        synchronized (mutex) {
            if (count == 0) return false;

            DecodedSlot* src = &slots[tail];

            outSlot.status = src.status;
            outSlot.frameIndex = src.frameIndex;
            outSlot.frame = src.frame;

            if (src.status == sdlffcd_DecodeStatus.SDLFFCD_DECODE_OK) {
                for (int i = 0; i < 8; i++) {
                    if (src.frame.data[i] !is null) {
                        swap(src.planeBuffers[i], outSlot.planeBuffers[i]);
                        outSlot.frame.data[i] = outSlot.planeBuffers[i].ptr;
                    } else {
                        outSlot.frame.data[i] = null;
                    }
                }
            }

            tail = (tail + 1) % capacity;
            count--;
            notFull.notify();
            return true;
        }
    }

    private double seekTargetPts = -1.0;
    private bool seekRequested = false;

    /**
     * Request decoder thread to seek to targetPts and flush queued slots in buffer.
     */
    void requestSeek(double targetPts) {
        synchronized (mutex) {
            seekTargetPts = targetPts;
            seekRequested = true;
            head = 0;
            tail = 0;
            count = 0;
            notFull.notifyAll();
        }
    }

    /**
     * Check if a seek request is pending. Returns true and outputs targetPts if pending.
     */
    bool checkAndClearSeekRequest(out double targetPts) {
        synchronized (mutex) {
            if (seekRequested) {
                targetPts = seekTargetPts;
                seekRequested = false;
                return true;
            }
            return false;
        }
    }

    /**
     * Flush all queued slots from buffer without requesting stream seek.
     */
    void clear() {
        synchronized (mutex) {
            head = 0;
            tail = 0;
            count = 0;
            notFull.notifyAll();
        }
    }

    /**
     * Signal worker thread to stop and unblock waiting condition variables.
     */
    void requestStop() {
        synchronized (mutex) {
            stopRequested = true;
            notFull.notifyAll();
            notEmpty.notifyAll();
        }
    }

    /**
     * Check if stop has been requested.
     */
    bool isStopRequested() {
        synchronized (mutex) {
            return stopRequested;
        }
    }
}
