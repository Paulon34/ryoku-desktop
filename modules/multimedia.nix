{ pkgs, config, lib, ... }:

let
  f = config.ryoku.features;
in
lib.mkMerge [
  (lib.mkIf f.multimedia {
    environment.systemPackages = with pkgs; [
      # Vídeo / áudio
      vlc
      ffmpeg
      mpv

      # Stream / gravação
      obs-studio

      # Música
      spotify

      # Edição
      audacity
      gimp
      imagemagick

      # PDFs / documentos
      libreoffice
      kdePackages.okular
    ];
  })

  # Virtual webcam for Android phone → scrcpy → browsers (Meet/WebRTC).
  # Pattern matches nixpkgs programs.obs-studio / droidcam modules.
  (lib.mkIf f.phoneTools {
    boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
    boot.kernelModules = [ "v4l2loopback" ];
    boot.extraModprobeConfig = ''
      options v4l2loopback devices=1 video_nr=2 card_label="Ryoku Phone Camera" exclusive_caps=1
    '';
  })
]
