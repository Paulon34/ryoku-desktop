{ config, lib, pkgs, ... }:

let
  f = config.ryoku.features;
in
{
  environment.systemPackages = with pkgs; [
    git
    gh
    curl
    wget

    nano
    vim
    neovim

    fastfetch
    htop
    btop
    tmux
    tree

    zip
    unzip
    p7zip

    jq
    ripgrep
    fd

    rsync
    file
    lsof

    pciutils
    usbutils

    gnupg
    openssl

    man-pages
    man-pages-posix
  ]
  ++ lib.optionals f.apps [
    rpi-imager
    qalculate-gtk
  ]
  ++ lib.optionals f.phoneTools [
    scrcpy
  ];

  security.polkit.extraConfig = lib.mkIf f.apps ''
    polkit.addRule(function(action, subject) {
      if (
        subject.isInGroup("wheel") &&
        action.id == "com.raspberrypi.rpi-imager.run"
      ) {
        return polkit.Result.AUTH_ADMIN_KEEP;
      }
    });
  '';

  programs.fish.enable = true;

  programs.nix-ld.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  environment.shells = with pkgs; [
    fish
  ];
}
