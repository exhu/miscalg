
subdir('shlib')

avutil_dep = dependency('libavutil')

clib_lib = static_library('clib',
  'clib.c',
  dependencies : [avutil_dep, shlib_dep]
)

clib_dep = declare_dependency(
  link_with : clib_lib,
  dependencies : [avutil_dep, shlib_dep],
  include_directories : include_directories('.'),
)
