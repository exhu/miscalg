# Debian 13 dependencies:
# apt install libsdl3-dev libavutil-dev libavcodec-dev libavformat-dev libswscale-dev
# libavcodec-dev depends on libswresample-dev

project('sdlffcd_clib', 'c',
  version : '0.1',
  default_options : ['warning_level=everything', 'c_std=c99'],
  meson_version: '>=1.7.0')


# DEPENDENCIES
# sdl3 3.4.10, ffmpeg libs 6.1.1

# libsdl.org
# prepend ~/.local/lib/pkgconfig to PKG_CONFIG_PATH before setup.
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

lib_src = ['sdlffcd_clib.c',
          ]

lib_sdlffc = static_library('sdlffcd_clib', lib_src,
                            dependencies: deps)
