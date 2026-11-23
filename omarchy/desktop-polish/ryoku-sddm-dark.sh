#!/usr/bin/env bash
# Ryoku Dark Minimal — install/restore SDDM theme without editing Omarchy files.
set -euo pipefail
umask 077

if (( EUID == 0 )); then
  echo "Execute as your regular user (sudo is requested only for individual writes)." >&2
  exit 1
fi

if (( $# != 1 )) || [[ "$1" != "--plan" && "$1" != "--apply" && "$1" != "--restore" ]]; then
  echo "Usage: bash omarchy/desktop-polish/ryoku-sddm-dark.sh --plan|--apply|--restore" >&2
  exit 2
fi

action="$1"
base="$(cd -- "$(dirname -- "$0")/.." && pwd)"
source_dir="$base/sddm/ryoku-dark"
theme_dir="/usr/share/sddm/themes/ryoku-dark"
override="/etc/sddm.conf.d/99-zz-ryoku-dark.conf"
backup_root="$HOME/.local/state/ryoku-omarchy/sddm-backups"

if [[ "$action" == "--plan" ]]; then
  printf 'Ryoku Dark Minimal plan (no changes):\n'
  printf '  Theme source: %s\n  Install path: %s\n  Dedicated override: %s\n' "$source_dir" "$theme_dir" "$override"
  printf '  Existing theme choices:\n'
  grep -H -E '^[[:space:]]*Current[[:space:]]*=' /etc/sddm.conf /etc/sddm.conf.d/*.conf 2>/dev/null || true
  printf '  Backup path: %s\n' "$backup_root"
  echo 'Apply never restarts SDDM. Restore only removes the dedicated Ryoku override.'
  exit 0
fi

# Build an exact expected config in a private, temporary file.
expected="$(mktemp)"
trap 'rm -f -- "$expected"' EXIT
printf '[Theme]\nCurrent=ryoku-dark\n' > "$expected"

if [[ "$action" == "--restore" ]]; then
  if [[ ! -e "$override" && ! -L "$override" ]]; then
    echo "Nothing to restore: Ryoku override does not exist."
    exit 0
  fi
  if [[ -L "$override" ]] || ! sudo cmp -s -- "$expected" "$override"; then
    echo "Refusing to delete an override that does not exactly match this installer." >&2
    exit 1
  fi
  sudo rm -- "$override"
  echo '✓ Ryoku override removed. Original Omarchy configuration remains intact.'
  echo 'Changes take effect at the next SDDM greeter start; no service was restarted.'
  exit 0
fi

# --apply
for filename in Main.qml metadata.desktop; do
  if [[ ! -f "$source_dir/$filename" || -L "$source_dir/$filename" ]]; then
    echo "Theme source is missing or a symlink: $filename" >&2
    exit 1
  fi
done

grep -qx 'QtVersion=6' "$source_dir/metadata.desktop" || {
  echo 'Refusing theme without QtVersion=6.' >&2
  exit 1
}
command -v sddm-greeter-qt6 >/dev/null || {
  echo 'sddm-greeter-qt6 not found.' >&2
  exit 1
}

# /etc/sddm.conf has higher precedence than config-directory drop-ins.
if [[ -f /etc/sddm.conf ]] && grep -Eq '^[[:space:]]*Current[[:space:]]*=' /etc/sddm.conf; then
  echo 'Found Current= in /etc/sddm.conf; refusing an override that would not take effect.' >&2
  exit 1
fi

if [[ -L "$theme_dir" ]] || [[ -L "$override" ]]; then
  echo 'Refusing to overwrite symlinked SDDM paths.' >&2
  exit 1
fi
if [[ -e "$theme_dir" ]]; then
  for filename in Main.qml metadata.desktop; do
    if [[ ! -f "$theme_dir/$filename" ]] || ! cmp -s -- "$source_dir/$filename" "$theme_dir/$filename"; then
      echo "Theme destination exists with different contents: $theme_dir" >&2
      exit 1
    fi
  done
fi

if [[ -e "$override" ]] && ! cmp -s -- "$expected" "$override"; then
  echo "A different override already exists: $override" >&2
  exit 1
fi

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup="$backup_root/$stamp"
mkdir -p -- "$backup"
for config in /etc/sddm.conf.d/10-theme.conf /etc/sddm.conf.d/99-omarchy-login.conf; do
  if [[ -f "$config" ]]; then
    cp -- "$config" "$backup/$(basename -- "$config")"
    chmod 0600 "$backup/$(basename -- "$config")"
  fi
done

sudo install -d -o 0 -g 0 -m 0755 -- "$theme_dir"
sudo install -o 0 -g 0 -m 0644 -- "$source_dir/Main.qml" "$theme_dir/Main.qml"
sudo install -o 0 -g 0 -m 0644 -- "$source_dir/metadata.desktop" "$theme_dir/metadata.desktop"
sudo install -o 0 -g 0 -m 0644 -- "$expected" "$override"

echo '✓ Ryoku Dark Minimal installed and selected for the next SDDM greeter.'
printf 'Backup of original theme selectors: %s\n' "$backup"
printf 'Preview the installed theme: sddm-greeter-qt6 --test-mode --theme %s\n' "$theme_dir"
echo 'No display-manager restart or reboot was triggered.'
echo 'Restore: bash omarchy/desktop-polish/ryoku-sddm-dark.sh --restore'
