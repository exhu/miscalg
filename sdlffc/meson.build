# apt install libsdl3-dev
project('sdlffc', 'c',
  version : '0.1',
  default_options : ['warning_level=everything', 'c_std=c99'],
  meson_version: '>=1.7.0')

#add_project_arguments('-fanalyzer', language: 'c')

sdl_dep = dependency('sdl3')

src = ['sdlffc.c', 'sdlffclib.c']

exe = executable('sdlffc', src, 
  install : true, dependencies: sdl_dep)

test('basic', exe)
