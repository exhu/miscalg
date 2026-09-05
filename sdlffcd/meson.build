# Debian 13 dependencies:
# apt install libsdl3-dev libavutil-dev libavcodec-dev libavformat-dev libswscale-dev
# libavcodec-dev depends on libswresample-dev

project('sdlffcd', ['c', 'd'],
  version : '0.1.0',
  default_options : [
    'warning_level=everything',
    'c_std=c99',
  ],
  meson_version: '>=1.7.0'
)

# C bridge libraries and their dependencies
subdir('sdlffcd_clib')

# D Source Files
d_sources = files(
  'source/sdlffcd/app.d',
  'source/sdlffcd/app_context.d',
  'source/sdlffcd/frame_ring_buffer.d',
  'source/sdlffcd/models.d',
  'source/sdlffcd/observable.d',
  'source/sdlffcd/player_controller.d',
  'source/sdlffcd/player_view.d',
  'source/sdlffcd/sdl_logger.d',
  'source/sdlffcd/sdlffcd_clib.d',
  'source/sdlffcd/sdlffcd_ffmpeg.d',
  'source/sdlffcd/sdlffcd_sdl.d',
  'source/sdlffcd/video_player.d',
)

# Include directories
d_include_dirs = include_directories('source')

# String import directory for assets (fonts, etc.)
d_import_dirs = include_directories('.')

# Main Executable
executable('sdlffcd',
  d_sources,
  include_directories : d_include_dirs,
  d_import_dirs : [d_import_dirs],
  dependencies : sdlffcd_clib_dep,
  install : true,
# links druntime statically
#  link_args: ['-link-defaultlib-shared=false'],
)

# Test Executable
test_exe = executable('sdlffcd_test',
  d_sources,
  d_unittest : true,
  include_directories : d_include_dirs,
  d_import_dirs : [d_import_dirs],
  dependencies : sdlffcd_clib_dep,
)

test('unittest', test_exe)
