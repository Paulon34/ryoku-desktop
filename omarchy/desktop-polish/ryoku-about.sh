#!/usr/bin/env bash
# Ryoku About branding: versioned Braille art of kanji 緑 for Omarchy 4.5.
# Replaces the About logo only; no modifications to /etc/fastfetch or shell.
set -Eeuo pipefail
mode="${1:---plan}"
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_file="$script_dir/ryoku-about.txt"
target="$HOME/.config/omarchy/branding/about.txt"
backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku-omarchy/backups"
pointer="$backup_dir/ryoku-about-last-backup"

case "$mode" in
  --plan|--apply|--restore) ;;
  *) echo "Uso: bash desktop-polish/ryoku-about.sh [--plan|--apply|--restore]" >&2; exit 2 ;;
esac

[[ "$EUID" -ne 0 ]] || { echo "Execute sem sudo." >&2; exit 1; }
[[ -f "$source_file" ]] || { echo "Logo do Ryoku nao encontrado: $source_file" >&2; exit 1; }

if [[ "$mode" == --plan ]]; then
  echo "Origem: $source_file"
  echo "Destino: $target"
  echo "Sera trocado somente o logo da janela Sobre / About do Omarchy."
  echo "Hardware, Fastfetch, cor e animacao existentes sao preservados."
  echo "Backup: $backup_dir"
  if [[ -L "$target" ]]; then
    echo "ATENCAO: logo de destino e um symlink; nao sera sobrescrito."
  elif [[ -f "$target" ]]; then
    cmp -s -- "$source_file" "$target" && echo "Status: ja aplicado" || echo "Status: pronto para aplicar"
  else
    echo "Status: about.txt ainda nao existe; script criara o arquivo"
  fi
  exit 0
fi

[[ ! -L "$target" ]] || { echo "Logo e um symlink. Recusado para evitar sobrescrever origem." >&2; exit 1; }

if [[ "$mode" == --restore ]]; then
  [[ -f "$pointer" ]] || { echo "Nenhum backup de logo salvo por este script." >&2; exit 1; }
  backup=$(cat -- "$pointer")
  [[ "$backup" == "$backup_dir"/ryoku-about-* && -d "$backup" ]] || {
    echo "Ponteiro de backup inesperado; recusado." >&2; exit 1;
  }
  [[ -f "$target" ]] && cmp -s -- "$source_file" "$target" || {
    echo "O logo foi alterado depois do Ryoku; nao vou sobrescrever sua versao atual." >&2; exit 1;
  }
  if [[ -f "$backup/original.txt" ]]; then
    cp -p -- "$backup/original.txt" "$target"
  elif [[ -f "$backup/was-absent" ]]; then
    rm -- "$target"
  else
    echo "Backup incompleto, abortando." >&2; exit 1;
  fi
  rm -- "$pointer"
  echo "Logo anterior restaurado."
  echo "Reabra o menu Sobre do Omarchy para conferir."
  exit 0
fi

if [[ -f "$target" ]] && cmp -s -- "$source_file" "$target"; then
  echo "Ja aplicado: logo Ryoku no About."
  exit 0
fi

mkdir -p -- "$backup_dir" "$(dirname -- "$target")"
backup=$(mktemp -d "$backup_dir/ryoku-about-XXXXXXXX")
chmod 700 "$backup"
if [[ -e "$target" ]]; then
  [[ -f "$target" ]] || { echo "Destino nao e arquivo regular; recusado." >&2; exit 1; }
  cp -p -- "$target" "$backup/original.txt"
else
  : > "$backup/was-absent"
fi
printf '%s\n' "$backup" > "$pointer"
chmod 600 "$pointer"
install -m 0644 -- "$source_file" "$target"

echo "Pronto! Kanji Ryoku no Fastfetch / Sobre do Omarchy."
echo "Backup: $backup"
echo "Para ver: omarchy-launch-about"
echo "Para desfazer: bash desktop-polish/ryoku-about.sh --restore"
