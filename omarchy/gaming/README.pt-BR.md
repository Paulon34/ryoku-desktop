# Ryoku Games — GPU dedicada por aplicativo (experimental)

Perfil opcional de **PRIME Render Offload** para notebooks Intel + NVIDIA. Mantém o Omarchy/Hyprland usando a GPU integrada e permite **solicitar** a dedicada apenas em jogos selecionados. Não altera drivers, módulos do kernel, modos do BIOS ou a configuração global do compositor.

**Status:** as variáveis foram salvas no Flatpak `com.mojang.Minecraft` e o runtime NVIDIA foi detectado no notebook de desenvolvimento, mas **o F3 do jogo após a alteração e o uso efetivo da NVIDIA ainda não foram confirmados**. CurseForge AppImage também aguarda teste. Não alegar PASS_REAL de jogos.

Referências: [NVIDIA PRIME Render Offload](https://download.nvidia.com/XFree86/Linux-x86_64/550.78/README/primerenderoffload.html) · [Flatpak overrides](https://docs.flatpak.org/en/latest/flatpak-command-reference.html).

## AppImage e programas nativos

A partir da pasta `omarchy/`, instale somente o *wrapper* opt-in, como usuário normal:

```bash
install -Dm755 gaming/ryoku-game "$HOME/.local/bin/ryoku-game"
```

Para testar um jogo:

```bash
"$HOME/.local/bin/ryoku-game" /caminho/para/jogo [argumentos...]
```

Para o CurseForge AppImage, substitua o caminho por seu AppImage **real**. Se seu lançador já usa argumentos adicionais, preserve-os após o caminho; não adicione `--no-sandbox` sem necessidade. O wrapper apenas define variáveis na árvore de processos iniciada por ele, sem criar um serviço permanente.

Não altere automaticamente lançadores `.desktop` ou a instalação do CurseForge. Um atalho próprio pode chamar o wrapper após o teste.

**Remover o wrapper:** `rm -- "$HOME/.local/bin/ryoku-game"` (se você não o modificou). Isso não afeta os drivers.

## Minecraft oficial em Flatpak

O aplicativo do notebook de desenvolvimento se chama `com.mojang.Minecraft`, não `minecraft-launcher`. Verifique seu ID com `flatpak list --app` antes de aplicar em outro computador.

Faça backup local da saída atual e **leia-a**, porque outros overrides podem existir:

```bash
mkdir -p "$HOME/.local/state/ryoku-omarchy"
flatpak override --user --show com.mojang.Minecraft \
  > "$HOME/.local/state/ryoku-omarchy/minecraft-overrides-before.txt"

flatpak override --user \
  --env=__NV_PRIME_RENDER_OFFLOAD=1 \
  --env=__GLX_VENDOR_LIBRARY_NAME=nvidia \
  --env=__VK_LAYER_NV_optimus=NVIDIA_only \
  com.mojang.Minecraft
```

Feche completamente o launcher e a Java, reabra pelo menu e confira o **F3** para ver a placa que renderiza. Enquanto o mundo está carregado, confira `nvidia-smi`. Se o F3 continuar mostrando Intel, o offload **não foi comprovado**: verifique se a Java herda o ambiente e se o runtime NVIDIA está disponível (`flatpak --gl-drivers` e `flatpak list --runtime`).

Para retirar **somente estas três preferências** do app (confira antes o backup, porque overrides preexistentes podem ser importantes):

```bash
flatpak override --user \
  --unset-env=__NV_PRIME_RENDER_OFFLOAD \
  --unset-env=__GLX_VENDOR_LIBRARY_NAME \
  --unset-env=__VK_LAYER_NV_optimus \
  com.mojang.Minecraft
```

O comando acima aplica a política de *unset* dessas variáveis no override do app; não restaura automaticamente valores preexistentes. Para uma restauração exata, consulte o backup.

## Steam

`%command%` só funciona nas **Opções de inicialização da Steam**, nunca num terminal Bash:

```text
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only %command%
```

Teste jogo por jogo. O processador continua responsável pela simulação, e V-Sync/limite de FPS podem mascarar ganho de desempenho. No modo híbrido, a GPU dedicada pode continuar energizada por outras razões, como saídas de vídeo externas.

Nenhuma conta, log, caminho absoluto pessoal ou informação de hardware foi incluída neste projeto.
