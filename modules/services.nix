{ config, lib, pkgs, ... }:

let
  f = config.ryoku.features;
in
lib.mkMerge [
  {
    # Firmware
    services.fwupd.enable = true;

    # Trim periódico para SSD
    services.fstrim.enable = true;

    # UDisks para montagem de discos no desktop
    services.udisks2.enable = true;

    # GVFS ajuda o gerenciador de arquivos com rede, lixeira, dispositivos etc.
    services.gvfs.enable = true;

    # Swap comprimida em RAM
    zramSwap.enable = true;

    # Evita travamentos severos por falta de memória
    services.earlyoom.enable = true;

    # Backend de bateria do DMS (Quickshell.Services.UPower via D-Bus).
    # Ativado sob demanda pelo D-Bus; ação crítica fica no default do NixOS.
    services.upower.enable = true;
  }

  (lib.mkIf f.flatpak {
    services.flatpak.enable = true;
    environment.systemPackages = [ pkgs.bazaar ];
  })

  # VPN mesh
  (lib.mkIf f.tailscale {
    services.tailscale.enable = true;
    environment.systemPackages = [ pkgs.tailscale ];
  })
]
