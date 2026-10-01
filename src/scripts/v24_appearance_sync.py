#!/usr/bin/env python3
"""Synchronize Serpantinum's selected mode with existing GTK/Qt/portal themes."""
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state"))
BACKUP = STATE / "serpantinum/v24-219-appearance-backup"
MANIFEST = BACKUP / "manifest.json"
HEX = re.compile(r"^#[0-9a-fA-F]{6}$")

DEFAULT = {
    "dark": {"base": "#1e1e2e", "mantle": "#181825", "text": "#cdd6f4",
             "surface0": "#313244", "surface1": "#45475a", "surface2": "#585b70",
             "subtext0": "#a6adc8", "mauve": "#cba6f7"},
    "light": {"base": "#eff1f5", "mantle": "#e6e9ef", "text": "#4c4f69",
              "surface0": "#ccd0da", "surface1": "#bcc0cc", "surface2": "#acb0be",
              "subtext0": "#6c6f85", "mauve": "#8839ef"},
}

def checksum(data):
    return hashlib.sha256(data).hexdigest()

def load_manifest():
    try:
        return json.loads(MANIFEST.read_text())
    except (OSError, ValueError):
        return {"files": {}, "gsettings": {}}

def save_manifest(data):
    BACKUP.mkdir(parents=True, exist_ok=True)
    tmp = MANIFEST.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2) + "\n")
    tmp.replace(MANIFEST)

def save(path, body, state):
    data = body.encode()
    if path.is_symlink():
        return False
    current = path.read_bytes() if path.is_file() else None
    if current == data:
        return False
    if path.exists() and not path.is_file():
        return False
    key = str(path)
    if key not in state["files"]:
        state["files"][key] = {"before": checksum(current) if current is not None else None}
        if current is not None:
            BACKUP.mkdir(parents=True, exist_ok=True)
            (BACKUP / (checksum(key.encode()) + ".bak")).write_bytes(current)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".v24-tmp")
    try:
        tmp.write_bytes(data)
        if current is not None:
            tmp.chmod(path.stat().st_mode & 0o777)
        tmp.replace(path)
    finally:
        tmp.unlink(missing_ok=True)
    state["files"][key]["after"] = checksum(data)
    return True

def gsettings(key, value=None):
    if not shutil.which("gsettings") or not os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
        return None
    command = ["gsettings", "set" if value is not None else "get", "org.gnome.desktop.interface", key]
    if value is not None:
        command.append(value)
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=4)
        return result.stdout.strip() if result.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None

def palette(mode):
    for name in ("qs_colors.json", "qs_matugen_colors.json"):
        path = STATE / "serpantinum" / name
        try:
            source = json.loads(path.read_text())
            source = source.get("colors", source)
            base = source["base"]
            if not isinstance(base, str) or not HEX.fullmatch(base):
                continue
            rgb = [int(base[i:i+2], 16) / 255 for i in (1, 3, 5)]
            light = sum(rgb[i] * w for i, w in enumerate((.2126, .7152, .0722))) > .48
            if light != (mode == "light"):
                continue
            return {k: (v if isinstance(v, str) and HEX.fullmatch(v) else DEFAULT[mode][k])
                    for k, v in ((key, source.get(key)) for key in DEFAULT[mode])}
        except (OSError, ValueError, KeyError, TypeError):
            pass
    return DEFAULT[mode].copy()

def gtk_settings(path, mode):
    if not path.is_file():
        return None
    content = path.read_text()
    value = "1" if mode == "dark" else "0"
    content, n = re.subn(r"(?m)^gtk-application-prefer-dark-theme\s*=.*$",
                         "gtk-application-prefer-dark-theme=" + value, content)
    if not n and "[Settings]" in content:
        content = content.replace("[Settings]", "[Settings]\ngtk-application-prefer-dark-theme=" + value, 1)
    content = re.sub(r"(?m)^(gtk-theme-name\s*=\s*)adw-gtk3(?:-dark)?\s*$",
                     r"\1adw-gtk3" + ("-dark" if mode == "dark" else ""), content)
    return content

def imperative_css(path, p):
    if not path.is_file():
        return None
    colors = {
        "window_bg_color": p["base"], "window_fg_color": p["text"],
        "view_bg_color": p["mantle"], "view_fg_color": p["text"],
        "headerbar_bg_color": p["base"], "headerbar_fg_color": p["text"],
        "sidebar_bg_color": p["mantle"], "sidebar_fg_color": p["text"],
        "card_bg_color": p["surface0"], "card_fg_color": p["text"],
        "popover_bg_color": p["surface0"], "popover_fg_color": p["text"],
        "dialog_bg_color": p["surface0"], "dialog_fg_color": p["text"],
        "borders": p["surface2"], "accent_bg_color": p["mauve"],
        "accent_color": p["mauve"], "accent_fg_color": p["base"],
        "theme_bg_color": p["base"], "theme_base_color": p["mantle"],
        "theme_fg_color": p["text"], "theme_text_color": p["text"],
    }
    content = path.read_text()
    for name, color in colors.items():
        content = re.sub(r"(?m)^(@define-color\s+" + re.escape(name) + r"\s+)#[0-9a-fA-F]{6}(\s*;)",
                         lambda m: m[1] + color + m[2], content)
    return content

def qt_palette(p):
    base, text, surface, mid, border, accent = (p[x] for x in
        ("base", "text", "surface0", "surface1", "surface2", "mauve"))
    active = [text, surface, border, surface, base, p["mantle"], text, text,
              text, mid, base, "#000000", accent, p["mantle"], p["subtext0"],
              accent, p["mantle"], text, border, text, p["subtext0"]]
    disabled = [p["subtext0"] if x == text else x for x in active]
    return "[ColorScheme]\n" + "".join(
        k + "=" + ", ".join(v) + "\n" for k, v in
        (("active_colors", active), ("inactive_colors", active), ("disabled_colors", disabled)))

def qt_qss(p):
    return (f'QWidget {{ color: {p["text"]}; selection-background-color: {p["mauve"]}; }}\n'
            f'QMainWindow, QDialog, QMenu {{ background-color: {p["base"]}; }}\n'
            f'QToolTip {{ background-color: {p["surface0"]}; color: {p["text"]}; '
            f'border: 1px solid {p["subtext0"]}; border-radius: 6px; padding: 5px; }}\n'
            f'QPushButton, QComboBox, QSpinBox, QDoubleSpinBox {{ background-color: {p["surface0"]}; '
            f'color: {p["text"]}; border: 1px solid {p["surface2"]}; '
            'border-radius: 7px; padding: 5px 9px; }\n'
            f'QPushButton:hover, QComboBox:hover {{ border-color: {p["mauve"]}; }}\n'
            f'QPushButton:checked, QPushButton:pressed {{ background-color: {p["mauve"]}; '
            f'color: {p["base"]}; }}\n'
            f'QProgressBar {{ background-color: {p["surface2"]}; border: 0; '
            'border-radius: 5px; text-align: center; }\n'
            f'QProgressBar::chunk {{ background-color: {p["mauve"]}; border-radius: 5px; }}\n')

def merge_ini(content, sections):
    """Replace only owned keys, retaining other settings and comments."""
    lines = content.splitlines()
    for section, values in sections.items():
        header = "[" + section + "]"
        start = next((i for i, line in enumerate(lines) if line.strip() == header), None)
        if start is None:
            lines.extend(["", header] + [k + "=" + v for k, v in values.items()])
            continue
        end = next((i for i in range(start + 1, len(lines)) if lines[i].lstrip().startswith("[")), len(lines))
        pending = dict(values)
        for i in range(start + 1, end):
            key = lines[i].split("=", 1)[0].strip()
            if key in values and "=" in lines[i] and not lines[i].lstrip().startswith(("#", ";")):
                lines[i] = key + "=" + values[key]
                pending.pop(key, None)
        lines[end:end] = [k + "=" + v for k, v in pending.items()]
    return "\n".join(lines).lstrip("\n") + "\n"

def sync_kde(chosen, state):
    # KDE follows the actual shell palette, including manually selected presets.
    try:
        source = json.loads((STATE / "serpantinum/qs_colors.json").read_text())
        source = source.get("colors", source)
        if all(isinstance(source.get(k), str) and HEX.fullmatch(source[k]) for k in chosen):
            chosen = {k: source[k] for k in chosen}
    except (OSError, ValueError, TypeError):
        pass
    p = chosen
    rgb = lambda color: ",".join(str(int(color[i:i+2], 16)) for i in (1, 3, 5))
    sections = {"General": {"Name": "Serpantinum v24", "ColorScheme": "SerpantinumV24"}}
    for name, bg, fg in (("Window", p["base"], p["text"]), ("View", p["mantle"], p["text"]),
                         ("Button", p["surface0"], p["text"]), ("Selection", p["mauve"], p["base"]),
                         ("Tooltip", p["surface0"], p["text"]), ("Complementary", p["mantle"], p["text"]),
                         ("Header", p["base"], p["text"])):
        sections["Colors:" + name] = {"BackgroundNormal": rgb(bg), "BackgroundAlternate": rgb(p["surface0"]),
            "ForegroundNormal": rgb(fg), "ForegroundInactive": rgb(p["subtext0"]),
            "ForegroundLink": rgb(p["mauve"]), "DecorationFocus": rgb(p["mauve"]),
            "DecorationHover": rgb(p["mauve"])}
    data = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local/share"))
    scheme = data / "color-schemes/SerpantinumV24.colors"
    changed = save(scheme, merge_ini("", sections), state)
    kde = CONFIG / "kdeglobals"
    changed |= save(kde, merge_ini(kde.read_text() if kde.is_file() else "", sections), state)
    qtcolors = CONFIG / "qt6ct/colors/SerpantinumV24.conf"
    changed |= save(qtcolors, qt_palette(p), state)
    qt = CONFIG / "qt6ct/qt6ct.conf"
    if qt.is_file():
        changed |= save(qt, merge_ini(qt.read_text(), {"Appearance": {
            "color_scheme_path": str(qtcolors), "custom_palette": "true"}}), state)
    engine = CONFIG / "hypr/hyprqt6engine.conf"
    if os.environ.get("QT_QPA_PLATFORMTHEME") == "hyprqt6engine":
        text = engine.read_text() if engine.is_file() else ""
        # A final theme block overrides the scheme without replacing fonts or style.
        text = re.sub(r"(?ms)^# BEGIN SERPANTINUM V24\n.*?^# END SERPANTINUM V24\n?", "", text)
        text = text.rstrip() + "\n# BEGIN SERPANTINUM V24\ntheme {\n    color_scheme = " + str(scheme) + "\n}\n# END SERPANTINUM V24\n"
        changed |= save(engine, text, state)
    return changed

def restore():
    state = load_manifest()
    for key, info in state["files"].items():
        path = Path(key)
        if path.is_symlink() or not path.is_file() or checksum(path.read_bytes()) != info.get("after"):
            print("Kept modified file:", path, file=sys.stderr)
            continue
        if info["before"] is None:
            path.unlink()
        else:
            backup = BACKUP / (checksum(key.encode()) + ".bak")
            if backup.is_file() and checksum(backup.read_bytes()) == info["before"]:
                path.write_bytes(backup.read_bytes())
    for key, val in state.get("gsettings", {}).items():
        if gsettings(key) == val["after"]:
            gsettings(key, val["before"])
    MANIFEST.unlink(missing_ok=True)

def run(mode):
    if mode == "auto":
        preference = gsettings("color-scheme")
        if preference in ("'prefer-dark'", "'default'", "'prefer-light'"):
            mode = "dark" if preference == "'prefer-dark'" else "light"
        else:
            gtk = CONFIG / "gtk-4.0/settings.ini"
            mode = "dark" if gtk.is_file() and re.search(
                r"(?m)^gtk-application-prefer-dark-theme\s*=\s*1\s*$", gtk.read_text()) else "light"
    state = load_manifest()
    chosen = palette(mode)
    kde_changed = sync_kde(chosen, state)
    changed = False
    for version in ("gtk-3.0", "gtk-4.0"):
        folder = CONFIG / version
        for path, content in ((folder / "settings.ini", gtk_settings(folder / "settings.ini", mode)),
                              (folder / "imperative-theme.css", imperative_css(folder / "imperative-theme.css", chosen))):
            if content is not None:
                changed |= save(path, content, state)
    qtconfig = CONFIG / "qt6ct/qt6ct.conf"
    if qtconfig.is_file() and "matugen.conf" in qtconfig.read_text():
        changed |= save(CONFIG / "qt6ct/colors/matugen.conf", qt_palette(chosen), state)
        qss = CONFIG / "qt6ct/qss/matugen-style.qss"
        if qss.is_file() and "matugen-style.qss" in qtconfig.read_text():
            changed |= save(qss, qt_qss(chosen), state)
    # Refresh a legacy stylesheet if qt6ct still references it after switching palettes.
    legacy_qss = CONFIG / "qt6ct/qss/matugen-style.qss"
    if qtconfig.is_file() and legacy_qss.is_file() and "matugen-style.qss" in qtconfig.read_text():
        kde_changed |= save(legacy_qss, qt_qss(chosen), state)
    preference = "'prefer-dark'" if mode == "dark" else "'default'"
    settings = {"color-scheme": preference}
    current_theme = gsettings("gtk-theme")
    if current_theme in ("'adw-gtk3'", "'adw-gtk3-dark'"):
        settings["gtk-theme"] = "'adw-gtk3-dark'" if mode == "dark" else "'adw-gtk3'"
    for key, target in settings.items():
        before = gsettings(key)
        if before is not None and before != target:
            if key not in state["gsettings"]:
                state["gsettings"][key] = {"before": before}
            if gsettings(key, target) is not None:
                state["gsettings"][key]["after"] = target
                changed = True
    if changed or kde_changed:
        save_manifest(state)
    if changed and shutil.which("systemctl") and os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
        for unit in ("xdg-desktop-portal-gtk.service", "xdg-desktop-portal-kde.service",
                     "xdg-desktop-portal.service"):
            try:
                subprocess.run(["systemctl", "--user", "try-restart", unit],
                               capture_output=True, timeout=5, check=False)
            except (OSError, subprocess.TimeoutExpired):
                pass
    print("Desktop appearance:", mode, "palette:", chosen["base"])

if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in ("dark", "light", "auto", "--restore"):
        sys.exit("Usage: v24_appearance_sync.py dark|light|auto|--restore")
    restore() if sys.argv[1] == "--restore" else run(sys.argv[1])
