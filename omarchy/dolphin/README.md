# Dolphin Sweet Ambar Blue — optional Ryoku profile

The tested look is a translucent dark Dolphin, white text, blue selection and **Papirus-Dark** folders. Ryoku's **Super+E** and **Super+Shift+F** shortcuts are in `omarchy/bindings.lua` (merged as [PR #2](https://github.com/Paulon34/ryoku-desktop/pull/2)), using Qt6ct/Kvantum **without changing the entire Omarchy session**.

**Third-party assets are not bundled.** Download Sweet and Papirus from their original projects, checking their respective licenses.

## Obtain the Sweet assets as your user

Requires Git, Dolphin, Qt6ct and Kvantum. Back up any existing paths before copying:

```bash
temp_dir="$(mktemp -d)"
git clone --depth 1 --branch Ambar-Blue \
  https://github.com/EliverLara/Sweet.git "$temp_dir/Sweet"

mkdir -p "$HOME/.config/Kvantum/Sweet-Ambar-Blue" \
  "$HOME/.local/share/color-schemes"

cp "$temp_dir/Sweet/kde/kvantum/Sweet-Ambar-Blue/"* \
  "$HOME/.config/Kvantum/Sweet-Ambar-Blue/"

cp "$temp_dir/Sweet/kde/colorschemes/SweetAmbarBlue.colors" \
  "$HOME/.local/share/color-schemes/"

rm -rf -- "$temp_dir"
```

Run `kvantummanager` and select **Sweet-Ambar-Blue**. Open `QT_QPA_PLATFORMTHEME=qt6ct qt6ct` and choose the Kvantum style, appropriate Sweet colors and **Papirus-Dark** icons. Note that Qt6ct/Kvantum settings may affect **other Qt6ct-managed Qt applications**; Ryoku's shortcut environment targets Dolphin, not the whole Omarchy session.

Choose the Sweet Ambar Blue color scheme in Dolphin as needed. On the tested development notebook, `kwriteconfig6 --file dolphinrc --group UiSettings --key ColorScheme SweetAmbarBlue` was used after backing up `~/.config/dolphinrc`.

Try the isolated launch:

```bash
QT_QPA_PLATFORMTHEME=qt6ct QT_STYLE_OVERRIDE=kvantum /usr/bin/dolphin --new-window
```

From `omarchy/`, run `python3 manage-bindings.py apply && hyprctl reload`, close old Dolphin windows and try **Super+E**. Blur/transparency depends on Kvantum and your compositor.

To remove Ryoku's entire managed keybinding block, run `python3 manage-bindings.py remove && hyprctl reload` from `omarchy/`. For appearance rollback, restore your own Qt6ct/Kvantum/Dolphin config backups. No complete personal dotfiles, secrets, third-party theme files or device identifiers are published.
