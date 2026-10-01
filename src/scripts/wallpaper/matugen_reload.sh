#!/usr/bin/env bash

source "$SCRIPT_DIR/../caching.sh"

quickshell -p "$MAIN_QML" ipc call theme reloadColors >/dev/null 2>&1 &

killall -USR1 .kitty-wrapped
"$HOME/.config/cava/reload-theme.sh" >/dev/null 2>&1 || true

wait
