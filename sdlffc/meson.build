# Debian 13 dependencies:
# apt install libsdl3-dev libavutil-dev libavcodec-dev libavformat-dev libswscale-dev
# libavcodec-dev depends on libswresample-dev

project('sdlffc', 'c',
  version : '0.1',
  default_options : ['warning_level=everything', 'c_std=c99'],
  meson_version: '>=1.7.0')

# If locally installed libs (e.g. SDL3 in ~/.local) are not found, run via:
#   ./build.sh
# which prepends ~/.local/lib/pkgconfig to PKG_CONFIG_PATH before setup.



# DEPENDENCIES
# sdl3 3.4.10, ffmpeg libs 6.1.1

# libsdl.org
sdl_dep = dependency('sdl3')

# ffmpeg dependencies
# libavutil -- common library shared between other ffmpeg libs
# pixel format info etc.
libavutil_dep = dependency('libavutil')
# libavcodec
# "The libavcodec library provides a generic encoding/decoding framework and contains multiple decoders and encoders for audio, video and subtitle streams, and several bitstream filters."
libavcodec_dep = dependency('libavcodec')
# libswscale
# "Pixel format conversion: ...for example from planar YUV420P to RGB24 packed."
libswscale_dep = dependency('libswscale')
# libswresample -- audio resampling
libswresample_dep = dependency('libswresample')
# libavformat -- muxing, demuxing
libavformat_dep = dependency('libavformat')

# C compiler & math library
cc = meson.get_compiler('c')
m_dep = cc.find_library('m', required : true)

# MAIN
deps = [sdl_dep,
        libavutil_dep,
        libavcodec_dep,
        libavformat_dep,
        libswscale_dep,
        libswresample_dep,
        m_dep,
       ]

lib_src = ['sdlffclib.c',
           'video_render.c',
           'demux_decoder.c',
           'playback_thread.c',
           'mailbox.c',
           'frame_queue.c',
          ]

lib_sdlffc = static_library('sdlffc_core', lib_src,
                            dependencies: deps)

sdlffc_dep = declare_dependency(link_with: lib_sdlffc,
                                dependencies: deps)

exe = executable('sdlffc', 'sdlffc.c',
                 install : true,
                 dependencies: sdlffc_dep)

exe_rewind = executable('test_rewind', 'test_rewind.c',
                        install : false,
                        dependencies: sdlffc_dep)

exe_pause_seek = executable('test_pause_seek', 'test_pause_seek.c',
                             install : false,
                             dependencies: sdlffc_dep)

exe_stream_end_pause = executable('test_stream_end_pause', 'test_stream_end_pause.c',
                                   install : false,
                                   dependencies: sdlffc_dep)

exe_frame_seek = executable('test_frame_seek', 'test_frame_seek.c',
                            install : false,
                            dependencies: sdlffc_dep)

exe_markers_cut = executable('test_markers_cut', 'test_markers_cut.c',
                             install : false,
                             dependencies: sdlffc_dep)

test_env = ['SDL_VIDEODRIVER=dummy', 'SDL_AUDIODRIVER=dummy']
test('basic', exe, args: [meson.project_source_root() / 'samplevideo.mp4'], env: test_env)
test('rewind_at_end', exe_rewind, args: [meson.project_source_root() / 'samplevideo.mp4'], env: test_env)
test('pause_seek', exe_pause_seek, args: [meson.project_source_root() / 'samplevideo.mp4'], env: test_env)
test('stream_end_pause', exe_stream_end_pause, args: [meson.project_source_root() / 'samplevideo.mp4'], env: test_env)
test('frame_seek', exe_frame_seek, args: [meson.project_source_root() / 'samplevideo.mp4'], env: test_env)
test('markers_cut', exe_markers_cut, args: [meson.project_source_root() / 'samplevideo.mp4'], env: test_env)
