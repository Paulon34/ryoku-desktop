#!/usr/bin/env bash
# Ryoku — persistent click-to-toggle dropdown tray (only edits user Tray.qml)
set -Eeuo pipefail
mode=${1:---plan}
conf="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
qml="$conf/plugins/io.github.tyrichards.tray/Tray.qml"
shell="$conf/shell.json"
backups="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku-omarchy/backups"
pointer="$backups/ryoku-tray-toggle-last"

case "$mode" in
  --plan|--apply|--restore) ;;
  *) echo "Uso: bash desktop-polish/tray-click-toggle.sh [--plan|--apply|--restore]" >&2; exit 2 ;;
esac
[[ $EUID -ne 0 ]] || { echo "Execute sem sudo." >&2; exit 1; }
[[ -f "$qml" && ! -L "$qml" ]] || { echo "Tray.qml do plugin nao encontrado: $qml" >&2; exit 1; }

if [[ "$mode" == --plan ]]; then
  echo "Alvo: $qml"
  echo "Ao clicar: abre/fixa; outro clique: fecha. Hover sozinho nao abre nem fecha."
  grep -q 'RYOKU_TRAY_CLICK_TOGGLE_BEGIN' "$qml" && echo "Toggle: ja instalado" || echo "Toggle: ainda nao instalado"
  grep -q 'RYOKU_TRAY_CHEVRON_BEGIN' "$qml" && echo "Seta animada: presente" || echo "Seta animada: ausente (aplique tray-chevron.sh)"
  [[ -f "$shell" ]] && jq -r '[.bar.layout[][] | select(.id=="omarchy.tray" or .id=="io.github.tyrichards.tray")] | "Bandejas: \(length) | dropdown ativo: \(any(.[]; .id=="io.github.tyrichards.tray" and .dropdown==true))"' "$shell"
  exit 0
fi

if [[ "$mode" == --restore ]]; then
  [[ -f "$pointer" ]] || { echo "Backup do toggle nao encontrado." >&2; exit 1; }
  saved=$(cat -- "$pointer")
  [[ "$saved" == "$backups"/tray-click-toggle-* && -d "$saved" && -f "$saved/Tray.qml" && -f "$saved/applied.sha256" ]] || { echo "Backup inesperado, recusado." >&2; exit 1; }
  current=$(sha256sum "$qml" | cut -d ' ' -f1)
  [[ "$current" == "$(cat "$saved/applied.sha256")" ]] || { echo "O plugin mudou desde o patch; nao vou apagar edicoes posteriores." >&2; exit 1; }
  cp -p -- "$saved/Tray.qml" "$qml"
  rm -- "$pointer"
  omarchy restart shell
  echo "Toggle anterior restaurado; backup: $saved"
  exit 0
fi

[[ -f "$shell" && ! -L "$shell" ]] || { echo "shell.json ausente." >&2; exit 1; }
[[ $(jq '[.bar.layout[][] | select(.id=="io.github.tyrichards.tray" and .dropdown==true)] | length' "$shell") == 1 ]] || { echo "Primeiro instale uma unica bandeja dropdown." >&2; exit 1; }
[[ $(jq '[.bar.layout[][] | select(.id=="omarchy.tray" or .id=="io.github.tyrichards.tray")] | length' "$shell") == 1 ]] || { echo "Detectei bandejas duplicadas. Corrija antes." >&2; exit 1; }

if grep -q 'RYOKU_TRAY_CLICK_TOGGLE_BEGIN' "$qml"; then
  [[ $(grep -c 'RYOKU_TRAY_CLICK_TOGGLE_BEGIN' "$qml") == 1 && $(grep -c 'RYOKU_TRAY_CLICK_TOGGLE_END' "$qml") == 1 ]] || { echo "Patch incompleto; recusado." >&2; exit 1; }
  echo "Ja instalado. Nada a fazer."
  exit 0
fi

# Do all source checks before creating backups or writing.
python3 - "$qml" --check <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding="utf-8")
anchors=[
 '  property bool expanded: clickExpanded || (hoverHeld && !exteriorPopoutOpen)',
 '  onExteriorPopoutOpenChanged: if (!exteriorPopoutOpen) clickExpanded = false',
 '  onHoverHeldChanged: if (!hoverHeld && dropdownMode) clickExpanded = false',
]
for old in anchors:
    if s.count(old)!=1:
        raise SystemExit("Trecho original inesperado: " + old)
begin=s.find("id: horizontalTray")
end=s.find("id: verticalTray",begin)
if begin<0 or end<0 or s[begin:end].count("              root.clickExpanded = true") != 1:
    raise SystemExit("Clique da bandeja horizontal nao corresponde ao fork fldc.")
if "RYOKU_TRAY_CLICK_TOGGLE_BEGIN" in s or "RYOKU_TRAY_CLICK_TOGGLE_END" in s:
    raise SystemExit("Patch parcial detectado; recusado.")
print("Codigo do plugin verificado.")
PY

mkdir -p "$backups"
saved=$(mktemp -d "$backups/tray-click-toggle-XXXXXXXX")
chmod 700 "$saved"
cp -p -- "$qml" "$saved/Tray.qml"

python3 - "$qml" <<'PY'
from pathlib import Path
import os,stat,sys,tempfile
p=Path(sys.argv[1])
s=p.read_text(encoding="utf-8")
def replace_one(a,b):
    global s
    if s.count(a)!=1:
        raise SystemExit("Arquivo modificado durante instalacao; recusado: "+a)
    s=s.replace(a,b,1)
replace_one(
 '  property bool expanded: clickExpanded || (hoverHeld && !exteriorPopoutOpen)',
 '  // RYOKU_TRAY_CLICK_TOGGLE_BEGIN\n'
 '  // Dropdown fica aberto ate o proximo clique; hover nao altera o estado.\n'
 '  property bool expanded: dropdownMode ? clickExpanded : (clickExpanded || (hoverHeld && !exteriorPopoutOpen))\n'
 '  // RYOKU_TRAY_CLICK_TOGGLE_END'
)
replace_one(
 '  onExteriorPopoutOpenChanged: if (!exteriorPopoutOpen) clickExpanded = false',
 '  onExteriorPopoutOpenChanged: if (!exteriorPopoutOpen && !dropdownMode) clickExpanded = false'
)
replace_one(
 '  onHoverHeldChanged: if (!hoverHeld && dropdownMode) clickExpanded = false',
 '  onHoverHeldChanged: if (!hoverHeld && !dropdownMode) clickExpanded = false'
)
a=s.find("id: horizontalTray")
b=s.find("id: verticalTray",a)
region=s[a:b]
old="              root.clickExpanded = true"
if region.count(old)!=1:
    raise SystemExit("Clique horizontal mudou; recusado.")
region=region.replace(old,"              root.clickExpanded = root.dropdownMode ? !root.clickExpanded : true",1)
s=s[:a]+region+s[b:]
fd,tmp=tempfile.mkstemp(prefix=".ryoku-toggle-",dir=str(p.parent))
try:
    os.fchmod(fd,stat.S_IMODE(p.stat().st_mode))
    with os.fdopen(fd,"w",encoding="utf-8") as out: out.write(s)
    os.replace(tmp,p)
finally:
    if os.path.exists(tmp): os.unlink(tmp)
print("Clique persistente Ryoku aplicado.")
PY

sha256sum "$qml" | cut -d ' ' -f1 > "$saved/applied.sha256"
printf '%s\n' "$saved" > "$pointer"
chmod 600 "$pointer"
omarchy restart shell
echo "Pronto. Clique abre e fixa; clique de novo fecha. Hover sozinho nao abre."
echo "Backup: $saved"
echo "Para desfazer: bash desktop-polish/tray-click-toggle.sh --restore"
