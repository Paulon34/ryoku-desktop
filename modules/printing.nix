{ config, lib, pkgs, ... }:

# Generic printing. Specific printers and vendor drivers belong to the host
# (hardware.printers.ensurePrinters, services.printing.drivers).

lib.mkIf config.ryoku.features.printing {
  services.printing = {
    enable = true;

    drivers = with pkgs; [
      hplip
      gutenprint
    ];
  };

  environment.systemPackages = with pkgs; [
    cups
    cups-filters
    ghostscript
    hplip
    system-config-printer
  ];

  # Descoberta de impressoras na rede
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
