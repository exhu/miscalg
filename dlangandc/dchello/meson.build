project('dchello', 'd',
  version : '0.1',
  default_options : ['warning_level=3'])

cmake = import('cmake')
myclib_sub = cmake.subproject('myclib')
myclib = myclib_sub.dependency('hellolib')

incdirs = include_directories('source')
executable('dchello',
           'source/app.d',
           'source/mymsg.d',
           dependencies: [myclib],
           include_directories: incdirs,
           install : true)
