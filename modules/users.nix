{ config, lib, pkgs, ... }:

# The Ryoku user and its Home Manager configuration.

let
  cfg = config.ryoku;
  f = cfg.features;
in
{
  users.users.${cfg.user.name} = {
    isNormalUser = true;
    description = cfg.user.description;
    shell = pkgs.fish;
    extraGroups =
      [ "wheel" "networkmanager" "video" ]
      ++ lib.optionals f.virtualization [ "docker" "libvirtd" ]
      ++ lib.optionals f.networkTools [ "wireshark" ]
      ++ cfg.user.extraGroups;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${cfg.user.name} = {
      imports = [ ../home/home.nix ] ++ cfg.user.homeModules;
    };
  };
}
