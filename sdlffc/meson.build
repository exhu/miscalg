# apt install libsdl3-dev
project('sdlffc', 'c',
  version : '0.1',
  default_options : ['warning_level=3', 'c_std=c99'],
  meson_version: '>=1.7.0')

sdl_dep = dependency('sdl3')

src = ['sdlffc.c', 'sdlffclib.c']

exe = executable('sdlffc', src, 
  install : true, dependencies: sdl_dep)

test('basic', exe)
