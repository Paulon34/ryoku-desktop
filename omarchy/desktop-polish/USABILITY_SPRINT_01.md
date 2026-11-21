# Ryoku Usability Sprint 01 — touchpad, downloads, audio, mídia e bandeja

Status: plano versionado; os comandos a seguir NÃO comprovam testes no notebook. Base alvo: Omarchy 4.5.0-3, Hyprland 0.56.2, Quickshell 0.3.x.

## 1. Zoom por pinça — PRONTO PARA TESTE
Ação nativa Hyprland (sem daemon/plugin):
`hl.gesture({ fingers = 2, direction = "pinch", action = "cursor_zoom", zoom_level = 1, mode = "live" })`.
Configuração adicionada apenas ao `~/.config/hypr/input.lua` do usuário, com marcadores Ryoku e backup. O zoom é do COMPOSITOR inteiro; **não** simula Ctrl+scroll nos aplicativos. O efeito final na gravação deve ser testado com o capturador PipeWire/OBS utilizado. Teste zoom e retorno a 100% usando o gesto contrário; o Omarchy já oferece reset de zoom por `Super+Ctrl+Alt+Z`. Não confundir escala do monitor com fator de zoom do compositor.

```bash
bash desktop-polish/pinch-zoom.sh --plan
bash desktop-polish/pinch-zoom.sh --apply
hyprctl configerrors
# Reverter exclusivamente o gesto:
bash desktop-polish/pinch-zoom.sh --remove
```

Validações de hardware: reconhecer dois dedos, smooth sem salto, manter Dwindle, funcionamento após restart, gravador captura o resultado, não prejudicar zoom das páginas no navegador.

Fontes: https://wiki.hypr.land/Configuring/Core/Binds/Gestures/ e https://github.com/aedyle/hypr-trackpad-gestures

## 2. Downloads junto dos workspaces — PLUGIN COMUNITÁRIO EXISTENTE
`jankeesvw.downloads` mostra recém-baixados e uma lista; permite arrastar o arquivo da lista para outra janela. Usa o diretório XDG Downloads, mostra badge de arquivos recentes; partial downloads ocultos.

```bash
# Revise a procedência e o código antes de instalar; plugins rodam dentro da shell.
omarchy plugin add https://github.com/jankeesvw/omarchy-downloads.git
omarchy plugin enable jankeesvw.downloads --section left --after omarchy.workspaces
```

O botão direito abre a pasta Downloads via gerenciador padrão (Dolphin). O clique esquerdo abre a lista. Testar nomes com acentos, arrastar para Firefox e comportamento em múltiplos monitores. Se o CLI não aceitar --after com --section, utilizar `omarchy bar move jankeesvw.downloads --section left --index N` conferindo o índice ou reposicionar arrastando o widget; não editar os outros widgets do arquivo shell.json.

Rollback: `omarchy plugin disable jankeesvw.downloads`. Para remover o clone: `omarchy plugin remove jankeesvw.downloads`.

Fonte: https://github.com/jankeesvw/omarchy-downloads

## 3. Som do desktop + voz — FASE DE DESIGN/PROTÓTIPO
Começar pelas funções nativas sem duplicar audio listeners:
- `omarchy.audio` tem slider de saída, apps individuais, slider de microfone e um medidor de **pico de entrada** enquanto o painel estiver aberto. Microfones virtuais não tipados podem não oferecer medidor.
- `omarchy.microphone` oferece atalho de mute e ajuste por scroll.
- À esquerda após Downloads, colocar `omarchy.microphone` seguido de `omarchy.audio`; preservar mixer/indicador de volume original se o usuário preferir à direita.

```bash
omarchy plugin enable omarchy.microphone --section left --after jankeesvw.downloads
omarchy bar move omarchy.audio --section left --after omarchy.microphone
```

Versão Ryoku a desenvolver: widget compacto `MIC | DESKTOP` com barras duplas para níveis reais (pico/DBFS, sem gravar áudio, sem enviar dados); popup de dois sliders para entrada e saída, mute individual e indicação de dispositivo. `PwNodePeakMonitor` em Quickshell suporta nodos de áudio, mas a avaliação de um **sink** como medidor do mix desktop depende de teste real do grafo PipeWire e das rotas efetivas do OBS. Os percentuais de ganho não indicam percepção relativa de loudness; peak e RMS/LUFS são diferentes. Não vender a comparação como avaliação automática da mixagem gravada. Medidores de microfone podem ativar indicador de captura de áudio; medir e confirmar custo/privacidade.

Fonte: https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Pipewire/PwNodePeakMonitor/ e `shell/plugins/panels/audio/Panel.qml` do Omarchy v4.5.0

## 4. Media Player — JÁ EXISTE
`omarchy.media` suporta:
- esquerdo: reproduzir/pausar;
- meio: avançar;
- roda do mouse: anterior/próxima;
- direito: popup com capa e controles.
Testar primeiro o menu do clique direito com Spotify; não adicionar widget concorrente sem necessidade.

Fonte: https://github.com/omacom/omarchy/blob/quattro/shell/plugins/bar/README.md

## 5. Tray para baixo — FORK EXISTENTE, NÃO INSTALAR AUTOMATICAMENTE
`fldc/omarchy-tray` é fork de TyRichards com modo dropdown específico (upstream TyRichards/main não tem o mesmo suporte). Widget ID `io.github.tyrichards.tray`. Conferido código-fonte `Tray.qml` do fork: `settings.dropdown === true` cria layer shell `omarchy-tray-dropdown`. NÃO habilitar a tray nova lado a lado com `omarchy.tray`, para evitar competirem pelo StatusNotifierWatcher.

```bash
omarchy plugin add https://github.com/fldc/omarchy-tray.git
# O helper valida se e mesmo o fork com suporte ao dropdown,
# faz backup e substitui apenas a entrada omarchy.tray do shell.json:
bash desktop-polish/tray-dropdown.sh --plan
bash desktop-polish/tray-dropdown.sh --apply
# Se nao gostar, reverter so a bandeja:
bash desktop-polish/tray-dropdown.sh --restore
```

### Seta animada do Ryoku
Com a bandeja dropdown única instalada e validada, o script `desktop-polish/tray-chevron.sh` altera **apenas** o `Tray.qml` local do fork, sem reescrever shell.json:
- Em uma barra no topo, fechada: seta lateral; **no clique ela gira 90° para baixo**, indicando a direção do dropdown; ao fechar volta suavemente;
- O ângulo segue `root.clickExpanded`, que é o estado fixado pelo clique no modo sticky, não o hover; barra inferior inverte o sentido, barra vertical permanece original;
- Duração de **240 ms** com easing; `--apply` atualiza também a versão v1 do script se já estiver aplicada, sem criar dois blocos;
- `--restore` preserva todo o restante de `Tray.qml`, revertendo apenas o bloco desta alteração; se havia v1, retorna a v1; se não havia animação, remove a personalização. O modo clique persistente permanece intacto.

```bash
bash desktop-polish/tray-chevron.sh --plan
bash desktop-polish/tray-chevron.sh --apply
# Reverter apenas a seta:
bash desktop-polish/tray-chevron.sh --restore
```

### Clique para abrir, clique para fechar (sem hover)
O script `tray-click-toggle.sh` muda apenas o `Tray.qml` local do fork (já instalado), preserva o script e animação da seta `tray-chevron.sh`, bem como `shell.json`, Omarchy oficial e outros widgets.

- No modo `dropdown: true`, pairar sobre a seta não abre a lista.
- **Primeiro clique:** seta aponta para baixo e os aplicativos aparecem no dropdown; permanece aberto ao sair com o mouse.
- **Segundo clique:** a lista recolhe e a seta retorna à direção original.
- O modo de barra vertical/horizontal sem dropdown continua com o comportamento original.
- Backup do arquivo modificado, verificação da versão exata do fork e recusa de restore se o arquivo mudar depois do patch.

```bash
bash desktop-polish/tray-click-toggle.sh --plan
bash desktop-polish/tray-click-toggle.sh --apply
# Para desfazer apenas o toggle:
bash desktop-polish/tray-click-toggle.sh --restore
```

Se as duas mudanças forem instaladas, reverta o **toggle primeiro** e a **seta depois**, para preservar a ordem dos backups. PASS_REAL requer teste na sessão do notebook, com mouse fora da bandeja e duas alternâncias sucessivas.

O fork tem README com exemplo que aponta para o repo TyRichards, mas para dropdown o **URL de clone deve ser fldc**. Testar hover, clique na setinha, ícones Steam/Discord, menus de contexto, telas múltiplas e hotkeys. Se falhar, restaurar só a entrada do tray para `omarchy.tray`; não remover a configuração inteira ou atualizar a shell no susto.

Fonte: https://github.com/fldc/omarchy-tray

## Estratégia geral
- Nenhuma alteração em arquivos da instalação do Omarchy (`/usr/share/omarchy` ou `/etc`).
- Não sobrescrever `shell.json` inteiro; preservar logo 緑, Google Agenda, energia e tema.
- Plugins externos devem ser revisados manualmente: QML roda código na sessão do usuário.
- PASS_REAL apenas após usuário confirmar comportamento no notebook e teste com gravador de tela.
