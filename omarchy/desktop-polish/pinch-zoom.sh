#!/usr/bin/env bash
# Ryoku pinch-to-zoom, native Hyprland 0.55+ Lua gesture.
# Does not install daemons/plugins and does not change Omarchy-owned files.
set -Eeuo pipefail

mode="${1:---plan}"
input_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
input="$input_dir/input.lua"
backups="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku-omarchy/backups"
begin="-- RYOKU_PINCH_ZOOM_BEGIN"
end="-- RYOKU_PINCH_ZOOM_END"

case "$mode" in
  --plan|--apply|--remove) ;;
  *) echo "Uso: bash desktop-polish/pinch-zoom.sh [--plan|--apply|--remove]" >&2; exit 2 ;;
esac

[[ "$EUID" -ne 0 ]] || { echo "Nao execute como root." >&2; exit 1; }
[[ -f "$input" && ! -L "$input" ]] || {
  echo "Nao encontrei arquivo regular em $input. Nao vou criar ou sobrescrever." >&2; exit 1;
}
command -v hyprctl >/dev/null || { echo "hyprctl ausente." >&2; exit 1; }

if [[ "$mode" == --plan ]]; then
  echo "Arquivo de usuario: $input"
  echo "Gesto nativo: dois dedos, pinch, cursor_zoom, live (continuo)."
  echo "Amplia a area de trabalho perto do cursor; nao simula Ctrl+scroll nos aplicativos."
  echo "Nao muda gestos de tres/quatro dedos, temas ou outros atalhos."
  if grep -Fq -- "$begin" "$input"; then
    echo "Status: bloco Ryoku ja presente"
  else
    echo "Status: ainda nao instalado"
  fi
  echo "Remocao: bash desktop-polish/pinch-zoom.sh --remove"
  exit 0
fi

mkdir -p "$backups"
backup="$backups/input-before-ryoku-pinch-$(date +%Y%m%dT%H%M%S%N).lua"
cp -p -- "$input" "$backup"

python3 - "$input" "$mode" <<'PY'
from pathlib import Path
import os
import stat
import sys
import tempfile

p = Path(sys.argv[1])
mode = sys.argv[2]
text = p.read_text(encoding="utf-8")
start = "-- RYOKU_PINCH_ZOOM_BEGIN"
finish = "-- RYOKU_PINCH_ZOOM_END"
if text.count(start) != text.count(finish) or text.count(start) > 1:
    raise SystemExit("Bloco Ryoku incompleto ou duplicado: nenhuma alteracao.")
if start in text:
    a = text.index(start)
    b = text.index(finish, a) + len(finish)
    while b < len(text) and text[b] == "\n":
        b += 1
    text = text[:a].rstrip("\n") + "\n" + text[b:].lstrip("\n")
    if text.strip():
        text = text.rstrip("\n") + "\n"

if mode == "--apply":
    # A mode=live gesture is continuous and zooms around the initial cursor.
    block = (
        "\n" + start + "\n"
        'hl.gesture({ fingers = 2, direction = "pinch", action = "cursor_zoom", '
        'zoom_level = 1, mode = "live" })\n'
        + finish + "\n"
    )
    text = text.rstrip("\n") + "\n" + block

fd, tmp = tempfile.mkstemp(prefix=".ryoku-pinch-", dir=str(p.parent))
try:
    os.fchmod(fd, stat.S_IMODE(p.stat().st_mode))
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, p)
finally:
    if os.path.exists(tmp):
        os.unlink(tmp)
PY

hyprctl reload
errors=$(hyprctl configerrors || true)
if [[ -n "$errors" && "$errors" != "ok" ]]; then
  echo "Hyprland reportou erros; restaurando input.lua automaticamente." >&2
  printf '%s\n' "$errors" >&2
  cp -p -- "$backup" "$input"
  hyprctl reload || true
  exit 1
fi
echo "Gesto Ryoku: $mode."
echo "Backup: $backup"
echo "Teste pinça com dois dedos sobre uma janela; para voltar: --remove."
