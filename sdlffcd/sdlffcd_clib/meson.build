# Debian 13 dependencies:
# apt install libsdl3-dev libavutil-dev libavcodec-dev libavformat-dev libswscale-dev
# libavcodec-dev depends on libswresample-dev

# DEPENDENCIES
# sdl3 3.4.10, SDL3_ttf-3.2.2, ffmpeg libs 6.1.1

# SDL dependencies
sdl3_dep = dependency('sdl3')
sdl3_ttf_dep = dependency('sdl3-ttf')

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
sdl_deps = [sdl3_dep, sdl3_ttf_dep, m_dep]
sdlffcd_sdl_lib = static_library('sdlffcd_sdl',
  'sdlffcd_sdl.c',
  dependencies : sdl_deps,
)

# FFmpeg Bridge Library Target
ffmpeg_deps = [
  libavutil_dep,
  libavcodec_dep,
  libavformat_dep,
  libswscale_dep,
  libswresample_dep,
  m_dep,
]
sdlffcd_ffmpeg_lib = static_library('sdlffcd_ffmpeg',
  'sdlffcd_ffmpeg.c',
  dependencies : ffmpeg_deps,
)

# Dependency Objects for Root Project Consumption
sdlffcd_sdl_dep = declare_dependency(
  link_with : sdlffcd_sdl_lib,
  dependencies : sdl_deps,
  include_directories : include_directories('.'),
)

sdlffcd_ffmpeg_dep = declare_dependency(
  link_with : sdlffcd_ffmpeg_lib,
  dependencies : ffmpeg_deps,
  include_directories : include_directories('.'),
)

sdlffcd_clib_dep = [sdlffcd_sdl_dep, sdlffcd_ffmpeg_dep]
#sdlffcd_clib_dep = [sdlffcd_ffmpeg_lib, sdlffcd_sdl_lib]
