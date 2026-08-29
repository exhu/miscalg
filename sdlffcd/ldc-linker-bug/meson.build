project('ldc-linker-bug', ['c', 'd'],
  version : '0.1.0',
  default_options : [
    'warning_level=everything',
    'c_std=c99',
  ],
)

subdir('clib')

d_sources = files('main.d')

executable('prog',
  d_sources,
  dependencies : clib_dep,
)
