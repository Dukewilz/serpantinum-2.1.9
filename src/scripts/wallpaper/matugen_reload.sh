#!/usr/bin/env bash

source "$SCRIPT_DIR/../caching.sh"

# Reload Serpantinum shell colors (updates QML UI)
quickshell -p "$MAIN_QML" ipc call theme reloadColors >/dev/null 2>&1 &

# Apply the new colors.conf from Serpantinum state and reload kitty
# (handles both matugen and custom theme modes, and both kitty/kitty-wrapped)
bash "$HOME/.local/bin/serpantinum-apply-kitty-theme.sh" >/dev/null 2>&1 &

"$HOME/.config/cava/reload-theme.sh" >/dev/null 2>&1 || true

wait
