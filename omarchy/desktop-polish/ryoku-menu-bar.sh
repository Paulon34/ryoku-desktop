#!/usr/bin/env bash
# Change only the native Omarchy bar's visible launcher to the Ryoku kanji.
# Keep the actual omarchy.menu plugin, menu IPC and keyboard shortcuts intact.
set -Eeuo pipefail

mode=${1:---plan}
config="${XDG_CONFIG_HOME:-$HOME/.config}"
shell="$config/omarchy/shell.json"
dest="$config/omarchy/bar/modules/ryoku-menu.qml"
src="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/ryoku-menu-widget.qml"
backups="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku-omarchy/backups"

case "$mode" in
  --plan|--apply|--remove) ;;
  *) echo "Uso: bash desktop-polish/ryoku-menu-bar.sh [--plan|--apply|--remove]" >&2; exit 2 ;;
esac
[[ $EUID -ne 0 ]] || { echo "Execute como usuario normal, sem sudo." >&2; exit 1; }
[[ -f "$shell" && ! -L "$shell" ]] || {
  echo "Arquivo shell.json ausente ou inesperado: $shell" >&2; exit 1;
}
[[ -f "$src" ]] || { echo "Widget do Ryoku nao encontrado: $src" >&2; exit 1; }

if [[ "$mode" == --plan ]]; then
  echo "Ryoku kanji: 緑 (verde; leitura on-yomi ryoku)"
  echo "Troca somente o icone do menu na barra; mantem o menu oficial ativo."
  echo "Clique esquerdo: menu Omarchy; direito: terminal."
  echo "Destino: $dest"
  python3 - "$shell" <<'PY'
import json,sys
with open(sys.argv[1],encoding="utf-8") as f:
    layout=json.load(f).get("bar",{}).get("layout",{})
for section,entries in layout.items():
    if not isinstance(entries,list):
        continue
    for entry in entries:
        if isinstance(entry,dict) and entry.get("id") in {"omarchy.menu","ryoku-menu"}:
            print("Item encontrado: "+entry["id"]+" na secao "+section)
PY
  if command -v fc-match >/dev/null 2>&1; then
    echo "Fonte japonesa disponivel via fontconfig: $(fc-match -f '%{family}' ':lang=ja')"
  fi
  echo "Se o kanji aparecer como quadrado, instale: sudo pacman -S --needed noto-fonts-cjk"
  exit 0
fi

if [[ "$mode" == --apply ]]; then
  [[ ! -L "$dest" ]] || {
    echo "Destino e um symlink; nao vou substituir." >&2; exit 1;
  }
  if [[ -e "$dest" ]] && ! cmp -s -- "$src" "$dest"; then
    echo "Ja existe um modulo Ryoku modificado em $dest; abortando para preservar." >&2
    exit 1
  fi
fi

mkdir -p "$backups"
backup="$backups/ryoku-menu-$(date +%Y%m%dT%H%M%S%N).json"
cp -a -- "$shell" "$backup"

# When applying, the QML has to be present before the shell.json is updated.
if [[ "$mode" == --apply ]]; then
  install -Dm0644 -- "$src" "$dest"
fi

python3 - "$shell" "$mode" <<'PY'
import json,os,stat,sys,tempfile
from pathlib import Path
p=Path(sys.argv[1])
mode=sys.argv[2]
data=json.loads(p.read_text(encoding="utf-8"))
layout=data.get("bar",{}).get("layout",{})
if not isinstance(layout,dict):
    raise SystemExit("Layout da barra nao encontrado; sem alteracoes.")
locations={}
for key,items in layout.items():
    if not isinstance(items,list):
        continue
    for i,item in enumerate(items):
        if isinstance(item,dict) and item.get("id") in ("omarchy.menu","ryoku-menu"):
            locations.setdefault(item["id"],[]).append((key,i))
old=locations.get("omarchy.menu",[])
new=locations.get("ryoku-menu",[])
if len(old)+len(new)!=1:
    raise SystemExit("Esperava exatamente um icone de menu na barra; sem alteracoes.")
if mode=="--apply" and old:
    section,idx=old[0]
    layout[section][idx]={"id":"ryoku-menu","type":"qml"}
elif mode=="--remove" and new:
    section,idx=new[0]
    layout[section][idx]={"id":"omarchy.menu"}
else:
    print("Configuracao ja esta no estado desejado.")
    raise SystemExit(0)
fd,tmp=tempfile.mkstemp(prefix=".ryoku-menu-",dir=str(p.parent))
try:
    os.fchmod(fd,stat.S_IMODE(p.stat().st_mode))
    with os.fdopen(fd,"w",encoding="utf-8") as out:
        json.dump(data,out,indent=2,ensure_ascii=False)
        out.write("\n")
    os.replace(tmp,p)
finally:
    if os.path.exists(tmp):
        os.unlink(tmp)
print("Barra atualizada: "+("緑 Ryoku" if mode=="--apply" else "logo original Omarchy"))
PY

omarchy restart shell
echo "Backup do shell.json: $backup"
if [[ "$mode" == --apply ]]; then
  echo "Para desfazer: bash desktop-polish/ryoku-menu-bar.sh --remove"
fi
