project('vcut', 'c', 'vala')
gnome = import('gnome')

add_project_arguments(['--vapidir', meson.current_source_dir(), '--pkg', 'vcutc', '--thread'],
                      language: 'vala')

glib_dep = dependency('glib-2.0')
gobject_dep = dependency('gobject-2.0')
gtk_dep = dependency('gtk+-3.0')
gdk_dep = dependency('gdk-3.0')
gdk_x11_dep = dependency('gdk-x11-3.0')
#epoxy_dep = dependency('epoxy')
mpv_dep = dependency('mpv')

cc = meson.get_compiler('c')
m_dep = cc.find_library('m', required : false)

sources = ['vcut.vala', 'vcut_exec.vala']
c_sources = ['vcutc.c']

resources = gnome.compile_resources('vcut_res', 'resources.xml')

c_code = static_library('vcutc', c_sources, dependencies: [mpv_dep, glib_dep])
executable('vcut', sources + resources, dependencies: [glib_dep, gobject_dep, gtk_dep, gdk_dep, gdk_x11_dep, m_dep], link_with: [c_code])