project('clib', 'c',
  version : '0.1',
  default_options : ['warning_level=3'])

lib = library('myclib', 'myclib/myclib.c', install:true)

exe = executable('clib', 'clib.c', link_with: lib,
  install : true)

test('basic', exe)
