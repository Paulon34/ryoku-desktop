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
