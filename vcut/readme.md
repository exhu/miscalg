vcut -- easy lossless video cut using ffmpeg, libmpv
====================================================

MIT license.
(C) 2017 Yury Benesh

This is my first Vala and GTK+ application, so it's quick and dirty in some way.

TODO
----
    - review code, markers logic via setters (ensure correct)
    + execute ffmpeg, busy indicator, stream output
    + execute button, overwrite confirmation
    + code refactoring (now it is a quick and dirty implementation to test things) -- remove redundant signal handlers code
    + Play AB, reset on other controls (except play/pause)
    + filename in window title
    + seek buttons
    + set A, B markers (swap if A is higher than B)
    + A, B, current time displays
    + generate ffmpeg command line
    + proper initialization of mpv callbacks
    + disable player window close
    + proper termination

Code by examples from https://github.com/mpv-player/mpv-examples/blob/master/libmpv/qt/qtexample.cpp

BUILD
-----
    Install:
        - meson build system (http://mesonbuild.com)
        - ninja
        - valac
        - libmpv-dev
        - libgtk+-3.0-dev
        - ffmpeg

    hg clone https://bitbucket.org/exhu/vcut
    mkdir build
    cd build
    meson ../
    ninja
    cd ..

USAGE
-----

    build/vcut myvideo.mp4