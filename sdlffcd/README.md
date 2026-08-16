# sdlffcd video trimming tool

`sdlffcd` is a standalone video player and lossless video trimming tool built with D, SDL3, FFmpeg, and SDL3_ttf.

## Features

- High-performance video playback powered by FFmpeg and SDL3.
- Frame-accurate single frame stepping.
- IN and OUT cut point markers for lossless trimming.
- Loop playback between IN and OUT markers.
- Lossless FFmpeg command generation with automatic cut timestamp naming.
- Multi-position and togglable timestamp & IN/OUT HUD overlay.
- Fullscreen mode support.

## Usage

```bash
./sdlffcd [options] <video_file>
```

### Command Line Options

- `--help`, `-h`: Show help message and controls.
- `--quit`: Quit application automatically when reaching the end of the video.

### Controls

| Key | Action |
|---|---|
| `Space` | Pause / Resume video playback |
| `Left` / `Right` | Seek backward / forward by 5 seconds |
| `[` / `]` | Step 1 frame backward / forward (pauses if playing) |
| `B` | Seek to video start frame (00:00:00, ignores IN-marker) |
| `E` | Seek to video end frame (ignores OUT-marker) |
| `I` | Set IN-marker (start of cut) to current frame time |
| `O` | Set OUT-marker (last frame of cut) to current frame time |
| `Shift + I` | Seek to IN-marker position (pauses if playing) |
| `Shift + O` | Seek to OUT-marker position (pauses if playing) |
| `L` | Toggle looping between IN and OUT markers |
| `M` | Toggle audio mute / unmute |
| `F` | Toggle fullscreen window mode |
| `V` | Cycle current time overlay position (Top-Left -> Top-Right -> Bottom-Right -> Bottom-Left -> Hidden) |
| `Enter` | Print lossless FFmpeg cut command to stdout |
| `Q` / `Esc` | Quit application (auto-prints FFmpeg command if markers modified) |

## Building & Testing

```bash
# Run unit tests
dub test

# Build executable
dub build

# Run application with sample video
./sdlffcd samplevideo.mp4
```

## License

MIT License
