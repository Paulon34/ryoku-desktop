<div align="center">

# RYOKU DESKTOP

**Uma experiência desktop reproduzível para NixOS. Seu hardware. Suas configurações. Seu estilo.**

Hyprland · DankMaterialShell · Quickshell · Material You · NixOS

[🇧🇷 Português](./README.pt-BR.md) · [🇬🇧 English](./README.md)

![NixOS](https://img.shields.io/badge/NixOS-x86__64-101922?style=flat-square&logo=nixos&logoColor=00c8f7)
![Hyprland](https://img.shields.io/badge/Hyprland-Wayland-101922?style=flat-square&logo=linux&logoColor=00c8f7)
![Licença](https://img.shields.io/badge/C%C3%B3digo-MIT-101922?style=flat-square)
![Estado](https://img.shields.io/badge/Estado-Pr%C3%A9--lan%C3%A7amento-101922?style=flat-square)

</div>

---

## 緑 Ryoku Omarchy Lab (Arch)

Já usa Omarchy em vez de NixOS? O [**Ryoku Omarchy Lab**](./omarchy/README.pt-BR.md) oferece identidade visual 緑, bandeja animada, atalhos, energia, zoom por pinça experimental e Google Agenda opcional. **Essa edição não instala NixOS.**

## `> o que é o ryoku?`

O **Ryoku Desktop** é uma experiência desktop configurável e opinativa, construída *sobre o NixOS*. Ele combina o [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) (DMS) personalizado sobre Quickshell, Hyprland, cores Material You baseadas no papel de parede e o aplicativo **Ryoku Settings**.

O Ryoku **não é uma distribuição Linux independente**, não substitui o instalador do NixOS e não é apenas uma coleção de dotfiles. É um conjunto reproduzível de módulos NixOS com um bootstrap que detecta hardware e exige revisão humana antes da ativação.

**Dois estilos de shell, um sistema:**

| **Quattro** (padrão) | **Ilhas** |
|---|---|
| Barra compacta de ponta a ponta, workspaces numerados, painéis emoldurados e animações contidas, inspirado no Omarchy Quattro. | Layout original do Ryoku, com ilhas flutuantes e aparência Material You mais suave. |

Ambos preservam os recursos do Ryoku, com configurações e paletas compartilhadas.

> **Capturas de tela** de Quattro, Ilhas e Ryoku Settings serão adicionadas em uma próxima atualização.

## `> recursos --listar`

- **Ryoku Settings:** aplicativo Qt 6/QML + C++ com português/inglês, busca por teclado, páginas de tela/rede/som/energia, integração Git/Nix e helper de Apply autorizado via Polkit.
- **Material You dinâmico:** Matugen gera paletas a partir do wallpaper e integra shell, terminal e Hyprland.
- **Perfis visuais:** *Econômico*, *Balanceado* e *Cinemático*, com ajuste automático por eventos de bateria e perfil de energia, sem polling recorrente novo.
- **Wallpapers:** imagem estática ou vídeo opcional via mpvpaper, com pôster para Material You e tela de bloqueio, além de modos de desempenho. **A edição pública não inclui vídeos.**
- **Experiência desktop:** barra DMS, launcher, Control Center, DankDash, notificações agrupadas, Não Perturbe, OSD, bandeja, bloqueio e SDDM adaptativo.
- **Sistema declarativo:** NixOS + Home Manager, lista de Flatpaks configurada por JSON, helper de Apply com host fixado e rollback por gerações do NixOS.
- **Perfis de instalação:** Minimal / Full, com recursos opcionais de desenvolvimento, jogos, virtualização e impressão.

### Minimal × Full

| | **Minimal** | **Full** |
|---|:---:|:---:|
| Desktop Ryoku, Quattro/Ilhas, Settings, Material You, SDDM | ✅ | ✅ |
| Wallpaper estático / suporte opcional a vídeo | ✅ | ✅ |
| Flatpak (sem aplicativos declarados por padrão) | ✅ | ✅ |
| Aplicativos extras e ferramentas de desenvolvimento | — | ✅ |
| Jogos, multimídia, virtualização, rede e impressão | — | ✅ |
| Pacotes proprietários necessários aos apps opcionais | — | ✅ |
| Ferramentas de segurança, celular, Tailscale, servidor SSH | Opcional | Opcional |

No ambiente de desenvolvimento, os closures medidos foram de aproximadamente **8,6 GiB (Minimal)** e **27,4 GiB (Full)**. Esses valores são *tamanhos de closures da Nix store*, não estimativas de download nem espaço livre mínimo.

## `> compatibilidade`

**Pré-requisitos:** um sistema **NixOS já instalado**, arquitetura **x86_64-linux**, Git, conexão para o build inicial e condições de revisar a configuração de boot gerada. O bootstrap **não instala NixOS nem particiona discos**.

| Plataforma | Validação |
|---|---|
| Notebook i5-11300H, Intel Iris Xe + NVIDIA GTX 1650 (PRIME) | Máquina física de desenvolvimento, em uso diário |
| QEMU/KVM com virtio-gpu / renderização por software | Minimal iniciou SDDM → Hyprland → DMS no primeiro login |
| Notebook híbrido Intel + NVIDIA; desktop AMD Navi 23 | Apenas fixtures de detecção |
| AMD físico, outras NVIDIA, HiDPI, LUKS, Secure Boot, hardware BIOS | **Ainda não validados fisicamente** |
| aarch64 / sistemas que não sejam NixOS | Não suportados pelo bootstrap |

O bootstrap identifica CPU, GPU, notebook/desktop, bateria, rede, monitores e ambiente de boot. **Ele não ativa o driver NVIDIA automaticamente**, não inventa UUIDs ou discos e não aprova configurações do bootloader.

O Ryoku mantém seus patches presos ao **DMS 1.5.3** e a uma revisão testada do nixpkgs. Atualizar `flake.lock` indiscriminadamente pode quebrar esses patches; a migração precisa de testes específicos.

## `> instalar --com-revisão`

> **Antes de começar:** faça backup de `/etc/nixos`, dos arquivos pessoais e da configuração de boot. Saiba escolher uma geração anterior do NixOS no menu de boot. O Ryoku modifica a configuração do sistema; revise tudo antes de ativar e evite aplicar remotamente sem acesso físico para recuperação.

**1. Clone o repositório.**

```bash
git clone https://github.com/Paulon34/ryoku-desktop ~/ryoku
cd ~/ryoku
```

**2. Prévia da detecção — não grava arquivos.**

```bash
nix --extra-experimental-features 'nix-command flakes' run .#bootstrap -- \
  --profile minimal --dry-run
```

**3. Gere a configuração da sua máquina.** Troque `minimal` por `full` para instalar os recursos extras.

```bash
nix --extra-experimental-features 'nix-command flakes' run .#bootstrap -- \
  --profile minimal
```

São gerados `hosts/<host>/default.nix`, `home.nix`, `boot.nix` e uma **cópia** de `/etc/nixos/hardware-configuration.nix`. O bootstrap não executa rebuild, não altera `/etc/nixos` e não ativa NVIDIA.

**4. Revise os arquivos antes de continuar.**

- Compare `hosts/<host>/boot.nix` com a configuração atual do NixOS, especialmente o bootloader e as opções EFI/BIOS. **Só depois da revisão**, defina `ryoku.host.bootReviewed = true;`.
- Confira usuário, teclado, monitores, recursos, hardware e `system.stateVersion` em `hosts/<host>/default.nix`.
- Se houver NVIDIA, revise o bloco comentado e os bus IDs PCI antes de habilitar o driver manualmente.
- Se o usuário escolhido ainda não existir, **planeje a configuração da senha para o primeiro login**: a conta só surge na ativação, não no build. Mantenha um administrador/console disponível e execute `sudo passwd <usuário>` após ativar, *antes* de sair ou reiniciar para uma tela de login inacessível.

**5. Adicione o host ao Git e faça o build.** O flake só enxerga arquivos rastreados pelo Git.

Nos exemplos abaixo, **substitua `workstation` pelo nome do host que o bootstrap gerou**:

```bash
git add hosts/workstation
nix --extra-experimental-features 'nix-command flakes' build \
  .#nixosConfigurations.workstation.config.system.build.toplevel
```

**6. Ative com plano de recuperação.** Um caminho cauteloso é registrar a configuração para o próximo boot e reiniciar com acesso físico, ou usar `nixos-rebuild test` para inspecionar a sessão antes da troca permanente.

```bash
sudo env NIX_CONFIG='experimental-features = nix-command flakes' \
  nixos-rebuild boot --flake .#workstation
```

Depois do primeiro boot, confira login/senha, rede, permissões e DMS. Se optar por `nixos-rebuild switch`, a ativação é imediata e pode interromper a sessão gráfica atual.

No primeiro login, os hooks criam os arquivos do DMS e aplicam a barra Quattro e o wallpaper padrão. Pode haver um pequeno atraso nessa primeira sessão.

### Conferência rápida

```bash
dms ipc call ryoku status
systemctl --user status dms.service
systemctl --user status ryoku-video-wallpaper.service
```

É normal o serviço de vídeo estar inativo se nenhum wallpaper em vídeo estiver selecionado.

## `> personalizar`

Abra o **Ryoku Settings** para mudar aparência, wallpapers, telas e demais opções disponíveis.

- **Mudanças ao vivo:** wallpaper estático/vídeo e perfil de efeitos podem ser aplicados na sessão atual.
- **Mudanças com Apply:** estilo da shell (Quattro/Ilhas), Flatpaks declarados, wallpaper do login e localização do clima entram na configuração NixOS/Home Manager. O Apply usa Polkit e caminhos/host fixados no build.
- **Fonte de configuração:** `ryoku/settings.json` (schema 1). O padrão público vem **sem cidade, vídeos ou Flatpaks declarados**.
- **Wallpaper em vídeo:** adicione seus próprios arquivos licenciados `.mp4`, `.webm`, `.mkv` ou `.mov` a `assets/wallpapers/`, faça `git add` (Git LFS é recomendado para arquivos grandes) e reconstrua com `sudo nixos-rebuild switch --flake .#<host>` para o Home Manager instalá-los em `~/.local/share/wallpapers`; depois selecione no Settings. A aceleração de vídeo depende da GPU e dos drivers disponíveis.

`nix flake check` sozinho não executa todos os builds de teste. Para uma validação mais ampla:

```bash
nix --extra-experimental-features 'nix-command flakes' flake check
nix --extra-experimental-features 'nix-command flakes' build .#checks.x86_64-linux.bootstrap
nix --extra-experimental-features 'nix-command flakes' build \
  .#nixosConfigurations.ryoku-minimal.config.system.build.toplevel
nix --extra-experimental-features 'nix-command flakes' build \
  .#nixosConfigurations.ryoku-full.config.system.build.toplevel
```

O teste de primeiro login em QEMU está disponível separadamente como `.#legacyPackages.x86_64-linux.vmTest` e exige KVM. O perfil **Full** compilou, mas o teste gráfico de primeiro login em VM cobriu **somente o Minimal**.

## `> atualizar / voltar`

Revise as alterações antes de atualizar: faça backup de `hosts/<host>/` e de `ryoku/settings.json` e use releases testadas do Ryoku. **Evite `nix flake update` indiscriminado** enquanto os patches continuarem fixados no DMS 1.5.3.

Para voltar a uma configuração anterior, selecione uma geração no boot ou, com o sistema em execução:

```bash
sudo nixos-rebuild switch --rollback
```

O Ryoku Settings também oferece gerenciamento de gerações na seção Nix e Atualizações.

## `> licença / créditos`

O código original do Ryoku é disponibilizado sob **MIT**. Componentes derivados mantêm suas próprias licenças — especialmente o overlay do SDDM astronaut em **GPL-3.0-or-later** e o subset da fonte Material Symbols em **Apache-2.0**. Os wallpapers procedurais públicos são **CC0-1.0**. Consulte [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md), [LICENSE](./LICENSE) e [LICENSES/](./LICENSES/).

O estilo Quattro tem como referência o [Omarchy Quattro](https://github.com/omacom/omarchy). A pesquisa de interações também considerou [43PR/dotfiles](https://github.com/43PR/dotfiles). O desktop é construído sobre NixOS, Home Manager, Hyprland, Quickshell, DMS, Matugen e mpvpaper. **O Ryoku não é afiliado a nem endossado por esses projetos.**

**Contribuições:** ao relatar problemas, informe hardware, versão do NixOS, commit do Ryoku, como reproduzir e logs sem dados pessoais. Não publique credenciais, números de série, UUIDs ou configuração privada de rede em issues.

<div align="center">

Feito para personalização, reprodutibilidade e open source.

**[English](./README.md)** · **[Créditos de terceiros](./THIRD_PARTY_NOTICES.md)**

</div>