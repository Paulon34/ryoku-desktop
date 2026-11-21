#!/usr/bin/env bash
# Replace stock tray widget with dropdown capable fork, preserving the bar config.
# Requires a separately reviewed and cloned fldc/omarchy-tray plugin.
set -Eeuo pipefail

mode="${1:---plan}"
conf="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
shell="$conf/shell.json"
plugin="$conf/plugins/io.github.tyrichards.tray"
backups="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku-omarchy/backups"
stock=omarchy.tray
custom=io.github.tyrichards.tray

case "$mode" in
  --plan|--apply|--restore) ;;
  *) echo "Uso: bash desktop-polish/tray-dropdown.sh [--plan|--apply|--restore]" >&2; exit 2 ;;
esac
[[ $EUID -ne 0 ]] || { echo "Nao execute com sudo." >&2; exit 1; }
[[ -f "$shell" && ! -L "$shell" ]] || {
  echo "Nao encontrei shell.json regular: $shell" >&2; exit 1;
}

if [[ "$mode" == --plan ]]; then
  echo "Plano: manter somente uma bandeja; trocar a original pelo fork com dropdown."
  echo "O icone original e os plugins de terceiros continuarao instalados."
  echo "O plugin deve ter sido instalado via fldc/omarchy-tray (nao TyRichards upstream)."
  [[ -f "$plugin/manifest.json" ]] && echo "Manifesto local: presente" || echo "Manifesto local: FALTA INSTALAR"
  [[ -f "$plugin/Tray.qml" ]] && grep -q 'dropdownMode:' "$plugin/Tray.qml" && echo "Codigo dropdown: confirmado no arquivo local" || echo "Codigo dropdown: NAO ENCONTRADO"
  echo "Se houver duas bandejas (original + plugin), --apply vai consolidar ambas mantendo a posicao original."
  python3 - "$shell" <<'PY'
import json,sys
d=json.load(open(sys.argv[1], encoding="utf-8"))
for section,items in d.get("bar",{}).get("layout",{}).items():
    if not isinstance(items,list): continue
    for x in items:
        if isinstance(x,dict) and x.get("id") in {"omarchy.tray","io.github.tyrichards.tray"}:
            print("Tray encontrada:", section, x)
PY
  exit 0
fi

if [[ "$mode" == --apply ]]; then
  [[ -f "$plugin/manifest.json" && -f "$plugin/Tray.qml" ]] || {
    echo "Plugin nao instalado. Instale e revise primeiro: omarchy plugin add https://github.com/fldc/omarchy-tray.git" >&2; exit 1;
  }
  [[ $(jq -r '.id' "$plugin/manifest.json") == "$custom" ]] || {
    echo "Manifesto inesperado; recusado." >&2; exit 1;
  }
  grep -q 'dropdownMode:' "$plugin/Tray.qml" || {
    echo "Clone sem suporte a dropdown. Confira URL do fork fldc." >&2; exit 1;
  }
fi

mkdir -p "$backups"
backup="$backups/tray-before-ryoku-$(date +%Y%m%dT%H%M%S%N).json"
cp -p -- "$shell" "$backup"

python3 - "$shell" "$mode" <<'PY'
import json, os, stat, sys, tempfile
from pathlib import Path
p=Path(sys.argv[1])
mode=sys.argv[2]
d=json.loads(p.read_text(encoding="utf-8"))
layout=d.get("bar",{}).get("layout")
if not isinstance(layout,dict):
    raise SystemExit("Layout invalido, nao alterado.")
# The plugin installation/enable may place the custom tray next to the stock
# one. Consolidate only one known stock and one known custom entry; never
# remove any unrelated widgets or their positions.
hits={}
for section, items in layout.items():
    if not isinstance(items, list): continue
    for i,item in enumerate(items):
        if isinstance(item,dict) and item.get("id") in ("omarchy.tray","io.github.tyrichards.tray"):
            hits.setdefault(item["id"],[]).append((section,i,item))
stock_hits=hits.get("omarchy.tray",[])
custom_hits=hits.get("io.github.tyrichards.tray",[])
if len(stock_hits)>1 or len(custom_hits)>1:
    raise SystemExit("Encontradas bandejas repetidas do mesmo tipo; revise manualmente, nenhuma alteracao.")
if not stock_hits and not custom_hits:
    raise SystemExit("Nenhuma bandeja conhecida na barra; nao alterado.")

if mode=="--apply":
    if stock_hits:
        section,index,stock=stock_hits[0]
        # Preserve stock position and all custom-tray settings already configured.
        current=custom_hits[0][2] if custom_hits else {}
        merged=dict(stock)
        merged.update(current)
        merged["id"]="io.github.tyrichards.tray"
        merged["dropdown"]=True
        # Drop the old custom position first, then find the stock anchor again.
        if custom_hits:
            custom_section,custom_index,_=custom_hits[0]
            del layout[custom_section][custom_index]
        section,index=next(
            (sec,i) for sec,items in layout.items() if isinstance(items,list)
            for i,item in enumerate(items) if isinstance(item,dict) and item.get("id")=="omarchy.tray"
        )
        layout[section][index]=merged
    else:
        section,index,custom=custom_hits[0]
        if custom.get("dropdown") is True:
            print("Ja existe apenas uma bandeja customizada com dropdown ativo.")
            raise SystemExit(0)
        layout[section][index]=dict(custom,dropdown=True)
elif mode=="--restore":
    if stock_hits and custom_hits:
        # In a mixed state, remove only the extra custom tray; retain stock.
        section,index,_=custom_hits[0]
        del layout[section][index]
    elif custom_hits:
        section,index,_=custom_hits[0]
        layout[section][index]={"id":"omarchy.tray"}
    else:
        print("Ja existe apenas a bandeja original.")
        raise SystemExit(0)
else:
    raise SystemExit("Modo inesperado.")
fd,tmp=tempfile.mkstemp(prefix=".ryoku-tray-",dir=str(p.parent))
try:
    os.fchmod(fd,stat.S_IMODE(p.stat().st_mode))
    with os.fdopen(fd,"w",encoding="utf-8") as f:
        json.dump(d,f,indent=2,ensure_ascii=False)
        f.write("\n")
    os.replace(tmp,p)
finally:
    if os.path.exists(tmp):
        os.unlink(tmp)
print("Bandeja atualizada:", layout[section][i])
PY

omarchy restart shell
echo "Backup: $backup"
echo "Para reverter somente a bandeja: bash desktop-polish/tray-dropdown.sh --restore"
