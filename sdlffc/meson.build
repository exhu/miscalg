# Debian 13 dependencies:
# apt install libsdl3-dev libavutil-dev libavcodec-dev libavformat-dev libswscale-dev
# libavcodec-dev depends on libswresample-dev

project('sdlffc', 'c',
  version : '0.1',
  default_options : ['warning_level=everything', 'c_std=c99'],
  meson_version: '>=1.7.0')

#add_project_arguments('-fanalyzer', language: 'c')

# DEPENDENCIES
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
# TODO do we need it?
# libavformat -- muxing, demuxing
libavformat_dep = dependency('libavformat')

# MAIN
deps = [sdl_dep,
        libavutil_dep,
        libavcodec_dep,
        libavformat_dep,
        libswscale_dep,
       ]

src = ['sdlffc.c',
       'sdlffclib.c',
      ]

exe = executable('sdlffc', src, 
                 install : true,
                 dependencies: deps)

# TODO tests
test('basic', exe)
