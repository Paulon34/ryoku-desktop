{ config, lib, pkgs, ... }:

lib.mkIf config.ryoku.features.gaming {
  # Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = false;
    dedicatedServer.openFirewall = false;
  };

  # Otimizações para jogos
  programs.gamemode.enable = true;

  # Micro-compositor para jogos
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  environment.systemPackages = with pkgs; [
    # Launchers / emulação
    lutris
    heroic
    rpcs3

    # Proton / Wine
    protonup-qt
    protontricks
    protonplus
    winetricks
    wineWow64Packages.stable

    # Performance / monitoramento
    mangohud

    # Gerenciamento de apps Windows
    bottles

    # Controle
    SDL2
  ];
}
