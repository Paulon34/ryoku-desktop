#!/usr/bin/env bash
# Power icon in Omarchy's right bar. Opens the *official* System menu
# (shutdown, reboot, suspend, logout, lock) rather than bypassing confirmation.
# No custom Quickshell service, no system files, no sudo.
set -Eeuo pipefail

mode=${1:---plan}
config=${XDG_CONFIG_HOME:-$HOME/.config}
target="$config/omarchy/shell.json"
state="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku-omarchy/backups"
id="ryoku.power-menu"

case "$mode" in
  --plan|--apply|--remove) ;;
  *) echo "Uso: bash desktop-polish/power-button.sh [--plan|--apply|--remove]" >&2; exit 2 ;;
esac

[[ $EUID -ne 0 ]] || { echo "Nao execute com sudo." >&2; exit 1; }
[[ -f $target && ! -L $target ]] || {
  echo "shell.json ausente ou symlink inesperado: $target" >&2; exit 1;
}

if [[ $mode == --plan ]]; then
  echo "Plano: botao de energia no canto direito da barra oficial do Omarchy."
  echo "Clique abre o menu System (suspender, desligar, reiniciar, sair, bloquear)."
  echo "Nao muda atalhos nem executa acoes de energia."
  jq -er '.bar.layout.right | type == "array"' "$target" >/dev/null
  jq -r --arg id "$id" 'if any(.bar.layout.right[]; .id == $id) then "Status: ja instalado" else "Status: nao instalado" end' "$target"
  exit 0
fi

mkdir -p "$state"
backup="$state/power-button-$(date +%Y%m%d-%H%M%S)"
cp -a -- "$target" "$backup"
echo "Backup: $backup"

python3 - "$target" "$mode" "$id" <<'PY'
import json, os, stat, sys, tempfile
from pathlib import Path

path, mode, item_id = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
data = json.loads(path.read_text(encoding="utf-8"))
right = data.get("bar", {}).get("layout", {}).get("right")
if not isinstance(right, list):
    raise SystemExit("bar.layout.right nao e uma lista; nao vou alterar.")
if any(not isinstance(item, dict) for item in right):
    raise SystemExit("Lista right inesperada; nao vou alterar.")
if mode == "--apply":
    existing = [item for item in right if item.get("id") == item_id]
    if existing:
        print("Botao de energia ja presente; nada a mudar.")
        raise SystemExit(0)
    right.append({
        "id": item_id,
        "type": "command",
        "exec": "printf '⏻\\n'",
        "interval": 300,
        "tooltip": "Energia: bloquear, suspender, sair, reiniciar ou desligar",
        "onClick": "omarchy-shell shell toggle omarchy.menu '{\"menu\":\"system\"}'",
    })
elif mode == "--remove":
    if not any(item.get("id") == item_id for item in right):
        print("Botao Ryoku nao encontrado; nada a remover.")
        raise SystemExit(0)
    right[:] = [item for item in right if item.get("id") != item_id]
fd, tmp = tempfile.mkstemp(prefix=".ryoku-power-", dir=str(path.parent))
try:
    os.fchmod(fd, stat.S_IMODE(path.stat().st_mode))
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.replace(tmp, path)
finally:
    if os.path.exists(tmp):
        os.unlink(tmp)
print("Configuracao da barra atualizada.")
PY

if command -v omarchy >/dev/null; then
  omarchy restart shell
fi
echo "Para desfazer so o botao: bash desktop-polish/power-button.sh --remove"
