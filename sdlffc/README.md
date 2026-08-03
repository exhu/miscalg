# sdlffc

**sdlffc** is a lightweight, performant (currenly software decoding only) video player and almost frame-accurate (using msec timing, not actual frame number) video trimming tool built with **C99**, **SDL3**, and **FFmpeg**.

It allows users to quickly inspect video files, step through frames, set precise IN and OUT cut markers, preview loops, and instantly generate or execute lossless FFmpeg stream-copy commands without re-encoding.

---

## Features

- **Smooth Playback & Audio Sync**: Asynchronous video/audio demuxing and decoding pipeline using FFmpeg libraries (`libavcodec`, `libavformat`, `libswscale`, `libswresample`).
- **Frame-Accurate Controls**: Step forward (`]`) or backward (`[`) by individual frames.
- **Precision Trimming**:
  - Set **IN** (`I`) and **OUT** (`O`) cut markers at current playback time.
  - Jump directly to IN (`Shift+I`) or OUT (`Shift+O`) positions.
  - Fast-jump to video start (`B`) or end (`E`).
- **A/B Looping**: Toggle seamless looping (`L`) between IN and OUT markers to preview cuts.
- **On-Screen Display (OSD) Overlay**:
  - Displays current timestamp, total duration, frame counters, and IN/OUT marker timestamps.
  - Toggle overlay position (`V`): Top-Left $\rightarrow$ Bottom-Right $\rightarrow$ Hidden.
- **Lossless Export**:
  - `Enter`: Print the exact stream-copy `ffmpeg` command to stdout for preview of `CTRL+ENTER` action.
  - `Ctrl + Enter`: execute the FFmpeg command to create new video from IN/OUT markers.
  - Auto-prints FFmpeg command upon quit (`Q` / `Esc`) if cut markers were modified so that to not lose the work.

---

## Dependencies

### System Packages (Debian / Ubuntu)

```bash
sudo apt update
sudo apt install build-essential meson ninja-build \
    libsdl3-dev libavcodec-dev libavformat-dev \
    libavutil-dev libswscale-dev libswresample-dev
```

*Note: On platforms where SDL3 is compiled and installed locally into `~/.local`, the provided `build.sh` script automatically configures `PKG_CONFIG_PATH` to find local libraries.*

---

## Building

Use Meson with the `_build` directory. The tests and default scripts expect `samplevideo.mp4` file in the root, any
short video will do.

### Quick Build Script

Use the provided helper script:

```bash
./build.sh
```

### Manual Build Procedure

```bash
meson setup _build
meson compile -C _build
```

---

## Running

You can launch the application using `run.sh` or directly executing the target binary with a path to a video file:

### Quick Run

```bash
./run.sh
```
Expects `samplevideo.mp4` file in the root

### Command Line Usage

```bash
./_build/sdlffc [OPTIONS] <path_to_video_file>
```

#### Options

- `-h`, `--help`: Display usage summary and keyboard shortcuts.

#### Example

```bash
./_build/sdlffc samplevideo.mp4
```

---

## Keyboard Controls & Shortcuts

| Key | Action |
| :--- | :--- |
| **`Space`** | Pause / Resume video playback |
| **`Left` / `Right`** | Seek backward / forward by 5 seconds |
| **`[` / `]`** | Step 1 frame backward / forward (pauses playback) |
| **`B`** | Seek to start frame (`00:00:00`) |
| **`E`** | Seek to end frame of video |
| **`I`** | Set **IN-marker** (start of cut) to current frame |
| **`O`** | Set **OUT-marker** (end of cut) to current frame |
| **`Shift + I`** | Seek to IN-marker position |
| **`Shift + O`** | Seek to OUT-marker position |
| **`L`** | Toggle A/B looping between IN and OUT markers |
| **`V`** | Cycle OSD overlay position (Top-Left $\rightarrow$ Bottom-Right $\rightarrow$ Hidden) |
| **`Enter`** | Print lossless FFmpeg stream-copy command to `stdout` |
| **`Ctrl + Enter`** | Execute FFmpeg export proces, waits until completed |
| **`Q` / `Esc`** | Quit application *(auto-prints FFmpeg command if markers modified)* |

---

## Running Tests

The test suite validates frame seeking, pause/rewind logic, stream end behavior, and cut marker updates using test executables:

```bash
meson test -C _build
```

---

## Architecture Overview

`sdlffc` uses a multi-threaded architecture to decouple media decoding from rendering:

- **Main Thread / UI (`sdlffclib.c`, `video_render.c`)**: Manages the SDL3 event loop, processes keyboard input, updates playback timers, renders video textures, and draws text OSD overlays.
- **Playback & Decoder Thread (`playback_thread.c`, `demux_decoder.c`)**: Demuxes stream packets, decodes video frames and audio samples asynchronously, and populates the frame queue.
- **Thread Synchronization (`mailbox.c`, `frame_queue.c`)**: Provides thread-safe communication queues between main UI and background decoder threads.

---

## License & Disclosure

This project is written in C99. Parts of the implementation utilize SDL3 test examples (`SDL3/test/testffmpeg.c`) and experimental code developed with LLM assistance.

zlib license.
