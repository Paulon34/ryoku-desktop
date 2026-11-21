#!/usr/bin/env bash
# One bar clock (date/time) that opens Omagoocal on click.
# The Google OAuth account, calendar backend, native shell and ${RYOKU_OLD_CLOCK_ID:-omarchy.clock} files are left intact.
set -Eeuo pipefail
MODE=${1:---plan}
CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}
PLUGIN="$CONFIG/omarchy/plugins/io.github.huligabuliga.omagoocal"
BAR="$PLUGIN/BarWidget.qml"
SHELL="$CONFIG/omarchy/shell.json"
BACKUPS="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku-omarchy/backups"
case "$MODE" in
  --plan|--apply|--restore) ;;
  *) echo "Usage: bash desktop-polish/unify-google-calendar.sh [--plan|--apply|--restore]" >&2; exit 2 ;;
esac
(( EUID != 0 )) || { echo "Execute como usuario normal." >&2; exit 1; }
if [[ "$MODE" == --plan ]]; then
  [[ -f "$BAR" ]] && echo "OK: Omagoocal BarWidget" || echo "FALTA: $BAR"
  [[ -f "$SHELL" ]] && echo "OK: shell.json" || echo "FALTA: $SHELL"
  echo "Vai substituir somente o texto do widget Omagoocal pela data e hora, desativar ${RYOKU_OLD_CLOCK_ID:-omarchy.clock} na barra e reiniciar a shell."
  echo "Nao modifica Google OAuth, eventos, tema, wallpaper nem instalacao dos plugins."
  exit 0
fi
if [[ "$MODE" == --restore ]]; then
  latest=$(ls -1dt "$BACKUPS"/unified-google-clock-* 2>/dev/null | head -1 || true)
  [[ -n "$latest" && -f "$latest/BarWidget.qml" && -f "$latest/shell.json" && -f "$BAR" ]] || {
    echo "Backup completo ou plugin instalado nao encontrado." >&2; exit 1;
  }
  cp -a -- "$latest/BarWidget.qml" "$BAR"
  cp -a -- "$latest/shell.json" "$SHELL"
  omarchy restart shell
  echo "Restaurado: $latest"
  exit 0
fi
[[ -f "$BAR" && -f "$SHELL" && -f "$PLUGIN/manifest.json" ]] || {
  echo "Omagoocal ou shell.json nao encontrado. Confira --plan." >&2; exit 1;
}
[[ $(jq -r .id "$PLUGIN/manifest.json") == io.github.huligabuliga.omagoocal ]] || {
  echo "Manifesto de plugin inesperado; recusado." >&2; exit 1;
}
if grep -q 'ryokuClockLabel:' "$BAR"; then
  echo "Relogio unificado ja aplicado. Nada a fazer."
  exit 0
fi
read -r -p "Unificar relogio + Google Agenda? [s/N] " answer
[[ "$answer" =~ ^[sS]$ ]] || exit 0
mkdir -p "$BACKUPS"
backup="$BACKUPS/unified-google-clock-$(date +%Y%m%d-%H%M%S)"
mkdir -m 0700 "$backup"
cp -a -- "$BAR" "$backup/BarWidget.qml"
cp -a -- "$SHELL" "$backup/shell.json"
if ! python3 - "$BAR" <<'PY'
import os
import stat
import sys
import tempfile
from pathlib import Path
p = Path(sys.argv[1])
s = p.read_text(encoding="utf-8")
a = '  readonly property bool iconOnly: vertical || !showNextEvent || !nextEvent'
b = '    text: root.iconOnly ? "" : root.label'
if s.count(a) != 1 or s.count(b) != 1 or "ryokuClockLabel" in s:
    raise SystemExit("Versao diferente de Omagoocal; nenhuma alteracao aplicada.")
s = s.replace(a, '  readonly property string ryokuClockLabel: now.toLocaleString(Qt.locale(I18n.formatLocale), "dddd HH:mm")\n  readonly property bool iconOnly: vertical', 1)
s = s.replace(b, '    text: root.vertical ? "" : root.ryokuClockLabel', 1)
fd, tmp = tempfile.mkstemp(prefix=".ryoku-clock-", dir=str(p.parent))
try:
    os.fchmod(fd, stat.S_IMODE(p.stat().st_mode))
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(s)
    os.replace(tmp, p)
finally:
    if os.path.exists(tmp):
        os.unlink(tmp)
PY
then
  echo "Patch recusado. Backup: $backup" >&2
  exit 1
fi
if ! omarchy plugin disable ${RYOKU_OLD_CLOCK_ID:-omarchy.clock}; then
  echo "Falha desativando o calendario antigo. Para voltar: bash desktop-polish/unify-google-calendar.sh --restore" >&2
  exit 1
fi
if ! omarchy plugin enable io.github.huligabuliga.omagoocal --section center; then
  echo "Falha ativando o novo relogio. Para voltar: bash desktop-polish/unify-google-calendar.sh --restore" >&2
  exit 1
fi
omarchy restart shell
echo "Pronto: a data/hora na barra abre Google Agenda ao clicar."
echo "Backup: $backup"
echo "Reverter: bash desktop-polish/unify-google-calendar.sh --restore"
