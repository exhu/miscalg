#!/usr/bin/env sh
# Wrapper around 'meson setup _build' that prepends ~/.local/lib/pkgconfig
# to PKG_CONFIG_PATH so locally installed libraries (e.g. SDL3) are found.
set -e

LOCAL_PC="$HOME/.local/lib/pkgconfig"
export PKG_CONFIG_PATH="${LOCAL_PC}${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

if [ ! -d "_build" ]; then
    meson setup _build "$@"
fi

exec meson compile -C _build "$@"
