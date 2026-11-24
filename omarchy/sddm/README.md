# 緑 Ryoku Dark Minimal — SDDM theme (Omarchy)

Minimal, pure-black login screen for SDDM **Qt 6**: white 緑 + RYOKU, white-outline password field, user avatar on its left, no bundled fonts, wallpaper or third-party assets.

**Scope:** only the SDDM login greeter. Does not change Omarchy's lock screen, Plymouth, Hyprland, desktop themes, or the original `/usr/share/sddm/themes/omarchy`.

## Install on Omarchy

Use the `feat/omarchy-ryoku-dark-sddm` branch until the PR is merged. From the repository's `omarchy/` directory:

```bash
bash desktop-polish/ryoku-sddm-dark.sh --plan
sddm-greeter-qt6 --test-mode --theme sddm/ryoku-dark
bash desktop-polish/ryoku-sddm-dark.sh --apply
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/ryoku-dark
```

**Exit the preview before using the next command.** Review the console for QML errors. The preview cannot prove real password authentication or user selection. Use the normal logout/login workflow to validate. **Do not run `sudo systemctl restart sddm` from your desktop session:** it may terminate the active session.

The installer copies exactly two theme files to `/usr/share/sddm/themes/ryoku-dark` and creates one own config file, `/etc/sddm.conf.d/99-zz-ryoku-dark.conf`, with:

```ini
[Theme]
Current=ryoku-dark
```

It does **not** rewrite existing `10-theme.conf` or `99-omarchy-login.conf`; snapshots of those files are kept under `~/.local/state/ryoku-omarchy/sddm-backups/`. It declines conflicting files, symlinks, and a higher-precedence `Current=` in `/etc/sddm.conf`. Existing accounts, passwords, PAM and session configuration are untouched.

The standard flow uses `userModel.lastUser`, matching Omarchy's original greeter. If an account is not preselected, **click the avatar** to type the username, then enter the password. The session preference follows the Omarchy `uwsm` entry, falling back to the last session.

## Restore safely

From your desktop terminal:

```bash
bash desktop-polish/ryoku-sddm-dark.sh --restore
```

Only the Ryoku override is removed, if its contents are unchanged. The original Omarchy theme is then selected by its existing configuration; the installed Ryoku theme files are intentionally left intact. Changes appear when SDDM starts its greeter next time.

**Emergency recovery if the login screen fails:** switch to a TTY with `Ctrl+Alt+F3` (on some notebooks use `Fn` too), sign in, and run:

```bash
sudo rm -- /etc/sddm.conf.d/99-zz-ryoku-dark.conf
sudo reboot
```

This removes only the dedicated Ryoku config and returns SDDM's theme selection to Omarchy. Do not delete `/usr/share/sddm/themes/omarchy` or edit PAM / autologin. Ensure another login route (TTY) works before your first real login test.

## Validation checklist

- [x] Pure-black/white layout approved in Qt6 test preview on the development notebook (local preview based on the same design)
- [ ] Validate the versioned theme's account-switch fallback and console in `--test-mode`
- [x] Confirm actual login and return to the Omarchy `uwsm` desktop on the development notebook (PASS_REAL, user confirmed 2026-11-23)
- [ ] Test restore to the stock Omarchy greeter
- [ ] Test multi-monitor behavior if needed

Status: actual login confirmed on the development notebook; manual account fallback, restore and multi-monitor checks are still pending. No user profile image or personal data is published.
