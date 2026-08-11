# Implementation Plan: Multithreaded Video Decoding with Ring Buffer

Implement background frame decoding on a dedicated worker thread using a thread-safe ring buffer in `source/frame_ring_buffer.d`, allowing the main thread in `app.d` to poll and render frames asynchronously without multi-threading SDL context calls.

---

## Architecture & Synchronization Overview

```mermaid
flowchart TD
    subgraph Main Thread (app.d Event Loop)
        A["decode_video_file()"] -->|"1. Instantiate FrameRingBuffer"| B["FrameRingBuffer(ringBufferCapacity)"]
        A -->|"2. Spawn Worker Thread"| C["Thread(&decodingWorker)"]
        A -->|"3. Poll Frame from Ring Buffer"| D["ringBuffer.pop(slot)"]
        D -->|"Frame Available"| E["sdlffcd_video_render_frame()"]
        E -->|"Frame Rate Timing"| F["Thread.sleep(frameDelayMs)"]
        D -->|"Stream Finished / Quit Event"| G["ringBuffer.requestStop() & Join Worker"]
    end
    subgraph Decoding Thread (Producer)
        C -->|"Loop while !ringBuffer.isStopRequested"| H["sdlffcd_video_decode_frame()"]
        H -->|"Copy Frame & Planes"| I["ringBuffer.push(frame)"]
        I -->|"Wait if Buffer Full"| J["notFull.wait()"]
    end
```

---

## User Review Required

> [!IMPORTANT]
> - `ringBufferCapacity` will be defined following D camelCase naming conventions (e.g. `enum ringBufferCapacity = 8;`) in `source/frame_ring_buffer.d`.
> - Ring buffer logic is decoupled into a dedicated new module [`source/frame_ring_buffer.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/frame_ring_buffer.d).
> - Plane memory for decoded frames (`data[0..2]`) is copied into slot-owned D byte buffers (`ubyte[][8]`). Plane buffers are allocated/resized on demand only when frame dimensions change; otherwise existing array memory is reused across frames to prevent GC overhead.
> - Background worker thread interacts exclusively with `FrameRingBuffer` and `sdlffcd_VideoContext` decoders. It does **not** call SDL `app` context functions (`sdlffcd_app_is_running`), ensuring thread safety. Worker thread termination is controlled by `ringBuffer.requestStop()`.

---

## Open Questions

None. All feedback incorporated into design.

---

## Proposed Changes

### Component: Ring Buffer Module (`source/frame_ring_buffer.d`)

#### [NEW] [`source/frame_ring_buffer.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/frame_ring_buffer.d)

Create `source/frame_ring_buffer.d` with `DecodedSlot` and `FrameRingBuffer`:

```d
module frame_ring_buffer;

import core.sync.mutex;
import core.sync.condition;
import sdlffcd_clib;

/// Default capacity for shared decoded frame ring buffer
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
    bool push(sdlffcd_DecodeStatus status, ref const(sdlffcd_VideoFrame) srcFrame, long frameIdx) {
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
                        size_t planeSize = cast(size_t)srcFrame.height * srcFrame.linesize[i];
                        
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
     * Returns true if slot was retrieved, or false if buffer is currently empty.
     */
    bool pop(out DecodedSlot slot) {
        synchronized (mutex) {
            if (count == 0) return false;

            slot = slots[tail];
            tail = (tail + 1) % capacity;
            count--;
            notFull.notify();
            return true;
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
```

---

### Component: D Application (`source/app.d`)

#### [MODIFY] [`source/app.d`](file:///home/yur/agy-projects/miscalg/sdlffcd/source/app.d)

1. Import `frame_ring_buffer`:
   ```d
   import frame_ring_buffer;
   ```

2. Implement `decodingWorker` thread function:
   ```d
   void decodingWorker(sdlffcd_VideoContext* vctx, FrameRingBuffer ringBuffer) {
       long decodedCount = 0;
       while (!ringBuffer.isStopRequested()) {
           sdlffcd_VideoFrame frame;
           sdlffcd_DecodeStatus status = sdlffcd_video_decode_frame(vctx, &frame);
           decodedCount++;
           bool pushed = ringBuffer.push(status, frame, decodedCount);
           if (!pushed || status != sdlffcd_DecodeStatus.SDLFFCD_DECODE_OK) {
               break;
           }
       }
   }
   ```

3. Update `decode_video_file`:
   - Instantiate `ringBuffer = new FrameRingBuffer(ringBufferCapacity)`.
   - Start background thread `decoderThread = new Thread(() => decodingWorker(vctx, ringBuffer)); decoderThread.start();`.
   - In main loop, while `sdlffcd_app_is_running(app)`:
     - Call `ringBuffer.pop(slot)`.
     - If frame popped: log head/tail frame metadata, call `sdlffcd_video_render_frame(app, vctx, &slot.frame)`, sleep `frameDelayMs`. Handle EOF / Error.
     - If buffer empty: sleep briefly (`Thread.sleep(dur!"msecs"(1))`) to yield CPU.
   - On cleanup (end of stream or window quit):
     ```d
     ringBuffer.requestStop();
     decoderThread.join();
     ```

---

## Verification Plan

### Automated Tests / Build
Compile the application with `dub build`:
```bash
dub build
```

### Manual Verification
Run the video player with `samplevideo.mp4`:
```bash
./sdlffcd samplevideo.mp4
```
Verify:
1. Video decodes smoothly and renders in real time.
2. Logging for head (first 5) and tail (last 5) frames output correctly.
3. Clean EOF message output upon completion.
4. Exiting during playback (closing window or pressing Q/ESC) requests stop, joins decoding thread, and exits cleanly without deadlocks or crashes.
