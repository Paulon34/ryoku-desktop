# 緑 Ryoku Omarchy Lab — edição pública experimental

Personalizações independentes para **Omarchy 4.5 / Hyprland / Quickshell** (Arch). Esta edição não é o [Ryoku Desktop NixOS](../README.pt-BR.md), não instala NixOS e não substitui o Omarchy.

**Inclui:** kanji 緑 na barra e no Fastfetch; atalhos Super+E (Dolphin) e Super+L (bloqueio); botão de energia; bandeja abrindo para baixo com seta animada e clique persistente; zoom por pinça experimental; e Google Agenda opcional.

## Instalação por recurso

Clone este repositório. Rode como usuário normal, sem `sudo`, e confira sempre o `--plan`:

```bash
git clone https://github.com/Paulon34/ryoku-desktop.git
cd ryoku-desktop/omarchy

python3 manage-bindings.py apply
hyprctl reload

bash desktop-polish/ryoku-menu-bar.sh --plan
bash desktop-polish/ryoku-menu-bar.sh --apply
bash desktop-polish/ryoku-about.sh --plan
bash desktop-polish/ryoku-about.sh --apply
bash desktop-polish/power-button.sh --plan
bash desktop-polish/power-button.sh --apply
```

Para o Dolphin: `sudo pacman -S --needed dolphin`. Evite forçar a remoção do Nautilus.

### Dolphin — Sweet Ambar Blue opcional (Super+E)

O atalho **Super+E** (e o alternativo Super+Shift+F) inicia o Dolphin com
`QT_QPA_PLATFORMTHEME=qt6ct` e `QT_STYLE_OVERRIDE=kvantum`, independentemente
do ambiente Qt do resto do Omarchy. **Super+Z não é alterado.** O tema e os
ícones não são incluídos no projeto: configure por conta própria o
[Kvantum Sweet Ambar Blue](https://github.com/EliverLara/Sweet/tree/Ambar-Blue/kde/kvantum/Sweet-Ambar-Blue),
o [esquema de cores Sweet](https://github.com/EliverLara/Sweet/blob/Ambar-Blue/kde/colorschemes/SweetAmbarBlue.colors)
e **Papirus-Dark**. O efeito transparente depende do Kvantum/compositor.

Requisitos: Dolphin, `qt6ct`, Kvantum, estilo escolhido no Kvantum Manager e
o esquema aplicado ao Dolphin. Teste o estilo **sem** mudar variáveis globais:

```bash
QT_QPA_PLATFORMTHEME=qt6ct QT_STYLE_OVERRIDE=kvantum /usr/bin/dolphin --new-window
```

Para instalar/atualizar os atalhos versionados (o script salva backup e preserva
a configuração não gerenciada):

```bash
cd ryoku-desktop/omarchy
python3 manage-bindings.py apply
hyprctl reload
```

Depois, feche todas as janelas do Dolphin e pressione **Super+E**. Se abrir
com o tema antigo, confirme o processo com `pgrep -a -x dolphin` e confira
as variáveis em `/proc/<PID>/environ`. Para reverter **apenas os atalhos Ryoku**:
`python3 manage-bindings.py remove && hyprctl reload`.


### Bandeja suspensa para baixo
Revise o código do [fork fldc/omarchy-tray](https://github.com/fldc/omarchy-tray) antes de instalar:

```bash
omarchy plugin add https://github.com/fldc/omarchy-tray.git
bash desktop-polish/tray-dropdown.sh --plan
bash desktop-polish/tray-dropdown.sh --apply
bash desktop-polish/tray-chevron.sh --plan
bash desktop-polish/tray-chevron.sh --apply
bash desktop-polish/tray-click-toggle.sh --plan
bash desktop-polish/tray-click-toggle.sh --apply
```

Reverter na ordem contrária: `tray-click-toggle.sh --restore`, `tray-chevron.sh --restore` e `tray-dropdown.sh --restore`. Não instale duas bandejas.

### Zoom por pinça (experimental)
```bash
bash desktop-polish/pinch-zoom.sh --plan
bash desktop-polish/pinch-zoom.sh --apply
# Voltar:
bash desktop-polish/pinch-zoom.sh --remove
```
É um zoom do compositor, **não** um `Ctrl+scroll` dos aplicativos. Teste se o seu gravador de tela captura o zoom.

### Google Agenda opcional
Revise e instale o [Omagoocal](https://github.com/huligabuliga/Omagoocal). Configure `RYOKU_OLD_CLOCK_ID` com o identificador do relógio que deseja ocultar (ex.: `omarchy.clock`) e execute `unify-google-calendar.sh --plan` antes de `--apply`. As credenciais Google permanecem locais.

**Segurança:** os scripts modificam apenas sua configuração local e geralmente criam backups em `~/.local/state/ryoku-omarchy/backups/`. Plugins QML de terceiros executam código na sessão; revise-os. Nada de drivers proprietários, credenciais, configurações pessoais nem wallpapers de licença incerta nesta edição. As funções foram testadas individualmente no notebook de desenvolvimento, mas a compatibilidade com outros sistemas não é garantida.

Código Ryoku original sob [MIT](../LICENSE). Os projetos externos têm licenças próprias e não estão incluídos: [créditos](THIRD_PARTY.md), [English](README.md), [plano de usabilidade](desktop-polish/USABILITY_SPRINT_01.md).
