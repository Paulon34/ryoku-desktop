#!/usr/bin/env bash
# Ryoku v2: animate the installed fldc dropdown tray chevron on real click.
# Upgrades the old Ryoku chevron patch in place, preserving sticky click-toggle.
set -Eeuo pipefail

mode=${1:---plan}
config="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
file="$config/plugins/io.github.tyrichards.tray/Tray.qml"
shell="$config/shell.json"
backups="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku-omarchy/backups"
pointer="$backups/ryoku-tray-chevron-v2-last"

case "$mode" in
  --plan|--apply|--restore) ;;
  *) echo "Uso: bash desktop-polish/tray-chevron.sh [--plan|--apply|--restore]" >&2; exit 2 ;;
esac

(( EUID != 0 )) || { echo "Execute como usuario normal, sem sudo." >&2; exit 1; }
[[ -f "$file" && ! -L "$file" ]] || {
  echo "Arquivo do plugin ausente/symlink inesperado: $file" >&2; exit 1;
}
command -v python3 >/dev/null || { echo "python3 ausente." >&2; exit 1; }

if [[ "$mode" == --plan ]]; then
  echo "Ryoku chevron v2: seta lateral quando fechado; gira 90 graus PARA BAIXO ao clicar."
  echo "Quando o dropdown esta aberto, a seta fica apontando para baixo ate o proximo clique."
  echo "Animacao no proprio icone, 240 ms; nao toca no script sticky toggle."
  echo "Arquivo: $file"
  if grep -q 'RYOKU_TRAY_CHEVRON_V2' "$file"; then
    echo "Status: v2 instalada"
  elif grep -q 'RYOKU_TRAY_CHEVRON_BEGIN' "$file"; then
    echo "Status: v1 detectada; --apply vai atualizar sem duplicar blocos"
  else
    echo "Status: nenhuma animacao Ryoku instalada; --apply vai adicionar"
  fi
  if grep -q 'RYOKU_TRAY_CLICK_TOGGLE_BEGIN' "$file"; then
    echo "Click-to-toggle: presente (compativel)"
  else
    echo "Click-to-toggle: NAO detectado; esta animacao nao modifica o estado de clique"
  fi
  if [[ -f "$shell" ]]; then
    jq -r '[.bar.layout[][] | select(.id=="omarchy.tray" or .id=="io.github.tyrichards.tray")] | "Bandejas: \(length); dropdown: \(any(.[]; .id=="io.github.tyrichards.tray" and .dropdown==true))"' "$shell"
  fi
  exit 0
fi

# The restore changes ONLY the chevron block, not the entire Tray.qml.
if [[ "$mode" == --restore ]]; then
  [[ -f "$pointer" ]] || { echo "Nenhum backup da v2 encontrado." >&2; exit 1; }
  dir=$(cat -- "$pointer")
  [[ "$dir" == "$backups"/tray-chevron-v2-* && -d "$dir" && -f "$dir/before.txt" && -f "$dir/after.txt" ]] || {
    echo "Backup da seta inesperado; recusado." >&2; exit 1;
  }
  python3 - "$file" "$dir" restore <<'PY'
from pathlib import Path
import os, stat, sys, tempfile
p, d, mode = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
current = p.read_text(encoding="utf-8")
before = (d/"before.txt").read_text(encoding="utf-8")
after = (d/"after.txt").read_text(encoding="utf-8")
if not after or current.count(after)!=1:
    raise SystemExit("A seta mudou depois do patch; nao vou sobrescrever outras personalizacoes.")
updated = current.replace(after, before, 1)
fd, tmp = tempfile.mkstemp(prefix=".ryoku-chevron-", dir=str(p.parent))
try:
    os.fchmod(fd, stat.S_IMODE(p.stat().st_mode))
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(updated)
    os.replace(tmp, p)
finally:
    if os.path.exists(tmp): os.unlink(tmp)
print("Animacao anterior restaurada. Sticky toggle preservado.")
PY
  rm -- "$pointer"
  omarchy restart shell
  echo "Backup usado: $dir"
  exit 0
fi

[[ -f "$shell" && ! -L "$shell" ]] || { echo "shell.json ausente; recusado." >&2; exit 1; }
[[ $(jq '[.bar.layout[][] | select(.id == "io.github.tyrichards.tray" and .dropdown == true)] | length' "$shell") == 1 ]] || {
  echo "Precisa existir uma bandeja dropdown do fork (dropdown=true)." >&2; exit 1;
}
[[ $(jq '[.bar.layout[][] | select(.id == "omarchy.tray" or .id == "io.github.tyrichards.tray")] | length' "$shell") == 1 ]] || {
  echo "Bandejas duplicadas; resolva antes de personalizar a seta." >&2; exit 1;
}

mkdir -p "$backups"
if [[ -f "$pointer" ]]; then
  echo "Um backup de v2 anterior ainda esta ativo. Use --plan ou --restore antes de outra aplicacao."
  if grep -q 'RYOKU_TRAY_CHEVRON_V2' "$file"; then exit 0; fi
  exit 1
fi

# Validate the exact upstream or old Ryoku block before any write.
dir=$(mktemp -d "$backups/tray-chevron-v2-XXXXXXXX")
chmod 700 "$dir"
cp -p -- "$file" "$dir/Tray.qml"
if ! python3 - "$file" "$dir" apply <<'PY'
from pathlib import Path
import os, stat, sys, tempfile

p, d = Path(sys.argv[1]), Path(sys.argv[2])
s = p.read_text(encoding="utf-8")
start = s.find("id: horizontalTray")
end = s.find("id: verticalTray", start)
if start < 0 or end <= start or s.count("RYOKU_TRAY_CHEVRON_BEGIN")>1:
    raise SystemExit("Estrutura do fork inesperada; recusado.")
region = s[start:end]
begin = '          // RYOKU_TRAY_CHEVRON_BEGIN\n'
endmark = '          // RYOKU_TRAY_CHEVRON_END\n'
new = (
    '          // RYOKU_TRAY_CHEVRON_BEGIN\n'
    '          // RYOKU_TRAY_CHEVRON_V2: segue o clique fixo, nunca o hover.\n'
    '          // FA chevron-left -> -90 graus = seta para baixo na barra superior.\n'
    '          textRotation: root.dropdownMode && root.clickExpanded\n'
    '            ? (root.dropdownBelow ? -90 : 90)\n'
    '            : 0\n'
    '          Behavior on textRotation {\n'
    '            NumberAnimation { duration: Style.duration(240); easing.type: Easing.InOutCubic }\n'
    '          }\n'
    '          // RYOKU_TRAY_CHEVRON_END\n'
)
if 'RYOKU_TRAY_CHEVRON_V2' in s:
    if s.count(new) == 1:
        print("Seta v2 ja instalada.")
        raise SystemExit(90)
    raise SystemExit("Patch v2 divergente. Nao vou sobrescrever.")
if region.count(begin)==1 and region.count(endmark)==1:
    a=region.index(begin)
    b=region.index(endmark,a)+len(endmark)
    old=region[a:b]
    # Restrict upgrades to the known v1 structure.
    if 'textRotation: root.dropdownMode' not in old or 'Behavior on textRotation' not in old:
        raise SystemExit("Patch v1 alterado; recusado.")
elif begin not in region and endmark not in region:
    needle='          text: "\\uf053"\n'
    if region.count(needle) != 1 or 'id: expandIcon' not in region:
        raise SystemExit("Seta original nao corresponde ao fork verificado.")
    old=''
    a=region.index(needle)+len(needle)
    b=a
else:
    raise SystemExit("Marcadores incompletos ou fora do lugar; recusado.")
updated_region=region[:a]+new+region[b:]
updated=s[:start]+updated_region+s[end:]
(d/"before.txt").write_text(old,encoding="utf-8")
(d/"after.txt").write_text(new,encoding="utf-8")
fd,tmp=tempfile.mkstemp(prefix=".ryoku-chevron-",dir=str(p.parent))
try:
    os.fchmod(fd,stat.S_IMODE(p.stat().st_mode))
    with os.fdopen(fd,"w",encoding="utf-8") as f:
        f.write(updated)
    os.replace(tmp,p)
finally:
    if os.path.exists(tmp): os.unlink(tmp)
print("Seta v2 aplicada: clique -> 90 graus -> apontando para dropdown.")
PY
then
  # Failed preflight must not leave a false active patch.
  rm -rf -- "$dir"
  exit 1
fi

printf '%s\n' "$dir" > "$pointer"
chmod 600 "$pointer"
omarchy restart shell
echo "Concluido! Clique na setinha duas vezes para testar abertura e fechamento."
echo "Backup: $dir"
echo "Reversao pontual: bash desktop-polish/tray-chevron.sh --restore"
