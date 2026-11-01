{ config, lib, pkgs, ... }:

lib.mkIf config.ryoku.features.virtualization {
  # Virtualização com KVM/QEMU
  virtualisation.libvirtd = {
    enable = true;
  };

  programs.virt-manager.enable = true;

  # Containers
  virtualisation.docker = {
    enable = true;
  };

  virtualisation.podman = {
    enable = true;

    dockerCompat = false;

    defaultNetwork.settings = {
      dns_enabled = true;
    };
  };

  environment.systemPackages = with pkgs; [
    # VMs
    qemu
    virt-manager
    virt-viewer

    # Containers
    docker-compose
    podman-compose
    distrobox

    # Utilidades
    spice
    spice-gtk
    swtpm
  ];
}
