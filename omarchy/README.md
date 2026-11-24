# 緑 Ryoku Omarchy Lab — experimental public edition

Optional Ryoku visual and usability customizations for **Omarchy 4.5 / Hyprland / Quickshell** (Arch). This edition is independent of the [Ryoku NixOS desktop](../README.md). It is **not** a distribution, third-party plugin bundle or universal installer.

## Features
- Japanese kanji 緑 in the Omarchy bar menu and the Fastfetch About screen
- Windows-style keyboard shortcuts, including Dolphin on Super+E and screen lock on Super+L
- One-click official power menu button
- Downward dropdown tray with animated chevron and click-to-toggle behavior (using an external plugin)
- Experimental pinch-to-zoom using native Hyprland Lua gestures
- Optional Google Calendar widget with an external plugin

## Setup
Clone this repo on Omarchy, then run scripts **as your normal user**, never as root:

```sh
git clone https://github.com/Paulon34/ryoku-desktop.git
cd ryoku-desktop/omarchy
python3 manage-bindings.py apply
hyprctl reload
bash desktop-polish/ryoku-menu-bar.sh --plan
bash desktop-polish/ryoku-menu-bar.sh --apply
bash desktop-polish/ryoku-about.sh --plan
bash desktop-polish/ryoku-about.sh --apply
bash desktop-polish/power-button.sh --plan
bash desktop-polish/power-button.sh --apply
```

Dolphin is optional: `sudo pacman -S --needed dolphin`. Keep or remove Nautilus only after checking dependencies.

### Dolphin — optional Sweet Ambar Blue (Super+E)

**Super+E** (and Super+Shift+F) launches Dolphin with
`QT_QPA_PLATFORMTHEME=qt6ct` and `QT_STYLE_OVERRIDE=kvantum`, independent
of the rest of the Omarchy Qt environment. **Super+Z is unchanged.**
Themes and icons are **not bundled**: set up the upstream
[Sweet Ambar Blue Kvantum theme](https://github.com/EliverLara/Sweet/tree/Ambar-Blue/kde/kvantum/Sweet-Ambar-Blue),
[Sweet color scheme](https://github.com/EliverLara/Sweet/blob/Ambar-Blue/kde/colorschemes/SweetAmbarBlue.colors),
and **Papirus-Dark** icons separately. Transparency also depends on Kvantum and
compositor configuration.

Requirements: Dolphin, `qt6ct`, Kvantum, the selected Kvantum style and Dolphin
color scheme. Test locally without changing the global session:

```bash
QT_QPA_PLATFORMTHEME=qt6ct QT_STYLE_OVERRIDE=kvantum /usr/bin/dolphin --new-window
```

Apply the versioned shortcuts with a backup (without replacing unmanaged config):

```bash
cd ryoku-desktop/omarchy
python3 manage-bindings.py apply
hyprctl reload
```

**Visual notebook test (2026-11-21):** Super+E opened Dolphin with the expected translucent dark view, white text, blue selection and Papirus icons. Inspecting the environment of the shortcut-launched process remains pending.

Close all Dolphin windows, then press **Super+E**. To remove only the Ryoku
shortcut overrides, use `python3 manage-bindings.py remove && hyprctl reload`.

### Dolphin and games — optional profiles

- [Dolphin Sweet Ambar Blue](dolphin/README.md): upstream assets, Qt6ct/Kvantum/Papirus setup, Super+E shortcut and rollback. **Appearance verified** on the development notebook; no bundled third-party assets.
- [Ryoku Games — PRIME Render Offload](gaming/README.md): optional `ryoku-game` wrapper plus Minecraft Flatpak, CurseForge AppImage and Steam instructions. **Experimental:** NVIDIA preference configured; actual game GPU selection not yet verified.

### Ryoku Dark Minimal login (SDDM Qt6)

Optional black-and-white greeter with white 緑 mark and avatar beside the password field. It does not replace the Omarchy theme or lock screen. Review the safe preview, install and rollback instructions in [Ryoku Dark SDDM](sddm/README.md).

```bash
bash desktop-polish/ryoku-sddm-dark.sh --plan
sddm-greeter-qt6 --test-mode --theme sddm/ryoku-dark
bash desktop-polish/ryoku-sddm-dark.sh --apply
```

This selects the theme via a separate config file and never restarts SDDM; login and return to the desktop were confirmed on a development notebook (2026-11-23). Manual user fallback and restore remain to be verified.

### Dropdown tray (external code)
Review the [fldc tray fork](https://github.com/fldc/omarchy-tray) before installing; plugins execute QML in your session. It replaces, not duplicates, the stock tray:

```sh
omarchy plugin add https://github.com/fldc/omarchy-tray.git
bash desktop-polish/tray-dropdown.sh --plan
bash desktop-polish/tray-dropdown.sh --apply
bash desktop-polish/tray-chevron.sh --plan
bash desktop-polish/tray-chevron.sh --apply
bash desktop-polish/tray-click-toggle.sh --plan
bash desktop-polish/tray-click-toggle.sh --apply
```

To undo, run `tray-click-toggle.sh --restore`, then `tray-chevron.sh --restore`, then `tray-dropdown.sh --restore`, in that order.

### Experimental pinch zoom
```sh
bash desktop-polish/pinch-zoom.sh --plan
bash desktop-polish/pinch-zoom.sh --apply
# Undo:
bash desktop-polish/pinch-zoom.sh --remove
```
This zooms the **compositor**, not a browser; screen recorders may capture it differently.

### Optional Google Calendar
Install and review [Omagoocal](https://github.com/huligabuliga/Omagoocal), then set `RYOKU_OLD_CLOCK_ID` to the actual redundant clock plugin identifier and run `unify-google-calendar.sh --plan` before `--apply`. No Google tokens are included or committed.

All scripts preserve the original Omarchy installation and change user-owned config only. Most create backups at `~/.local/state/ryoku-omarchy/backups`. Features were individually tested on a development notebook; compatibility elsewhere is not guaranteed.

MIT for Ryoku original code; third-party components are independently licensed and **not bundled**. See [Credits](THIRD_PARTY.md), [Português](README.pt-BR.md), and the [usability plan](desktop-polish/USABILITY_SPRINT_01.md).
