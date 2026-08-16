# Debian 13 dependencies:
# apt install libsdl3-dev libavutil-dev libavcodec-dev libavformat-dev libswscale-dev
# libavcodec-dev depends on libswresample-dev

project('sdlffcd_clib', 'c',
  version : '0.2',
  default_options : ['warning_level=everything', 'c_std=c99'],
  meson_version: '>=1.7.0')

# DEPENDENCIES
# sdl3 3.4.10, SDL3_ttf-3.2.2, ffmpeg libs 6.1.1

# SDL dependencies
sdl_dep = dependency('sdl3')
sdlttf_dep = dependency('sdl3-ttf')

# FFmpeg dependencies
libavutil_dep = dependency('libavutil')
libavcodec_dep = dependency('libavcodec')
libavformat_dep = dependency('libavformat')
libswscale_dep = dependency('libswscale')
libswresample_dep = dependency('libswresample')

# C compiler & math library
cc = meson.get_compiler('c')
m_dep = cc.find_library('m', required : true)

# SDL Bridge Library Target
sdl_deps = [sdl_dep, sdlttf_dep, m_dep]
lib_sdl = static_library('sdlffcd_sdl', ['sdlffcd_sdl.c'],
                         dependencies: sdl_deps)

# FFmpeg Bridge Library Target
ffmpeg_deps = [libavutil_dep, libavcodec_dep, libavformat_dep, libswscale_dep, libswresample_dep, m_dep]
lib_ffmpeg = static_library('sdlffcd_ffmpeg', ['sdlffcd_ffmpeg.c'],
                            dependencies: ffmpeg_deps)
