{ lib, ... }:

# A machine-independent Ryoku host used to build and boot-test the reusable
# core (nixosConfigurations.ryoku-minimal / ryoku-full and the VM test). Its
# disk layout is a placeholder: real machines get theirs from
# scripts/ryoku-bootstrap, which copies /etc/nixos/hardware-configuration.nix.

{
  networking.hostName = lib.mkDefault "ryoku";

  ryoku.user = {
    name = lib.mkDefault "ryoku";
    description = "Ryoku";
  };

  # Generic machines: VA-API for whatever Mesa supports; no vendor drivers.
  hardware.graphics.enable = true;

  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault false;

  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
  };

  time.timeZone = lib.mkDefault "UTC";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  system.stateVersion = "26.05";
}
