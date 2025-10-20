# apt install libsdl3-dev
project('sdlffc', 'c',
  version : '0.1',
  default_options : ['warning_level=3'])

sdl_dep = dependency('sdl3')

src = ['sdlffc.c']

exe = executable('sdlffc', src, 
  install : true, dependencies: sdl_dep)

test('basic', exe)
