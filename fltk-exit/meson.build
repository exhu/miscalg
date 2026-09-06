project('fltk_exit_demo', 'cpp',
  version : '0.1',
  default_options : ['warning_level=3', 'cpp_std=c++17'])

# Locate the fltk-config utility provided by libfltk1.3-dev
fltk_config = find_program('fltk-config', required : true)

# Extract CXX and linker flags from fltk-config
cxx_args = run_command(fltk_config, '--cxxflags', check : true).stdout().strip().split()
link_args = run_command(fltk_config, '--ldflags', check : true).stdout().strip().split()

# Wrap flags into a reusable dependency object
fltk_dep = declare_dependency(
  compile_args : cxx_args,
  link_args : link_args
)

executable('exit_demo',
  'main.cpp',
  dependencies : [fltk_dep],
  install : false
)
