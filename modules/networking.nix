{ config, lib, pkgs, ... }:

let
  cfg = config.ryoku;
  f = cfg.features;
in
lib.mkMerge [
  {
    networking.networkmanager.enable = true;

    # Firewall ligado por padrão
    networking.firewall = {
      enable = true;

      # Começa fechado.
      # A gente abre portas específicas depois, se precisar.
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
    };

    environment.systemPackages = with pkgs; [
      # Interface gráfica de rede
      networkmanagerapplet
    ];
  }

  (lib.mkIf f.ssh {
    services.openssh = {
      enable = true;

      settings = {
        PasswordAuthentication = cfg.ssh.passwordAuthentication;
        PermitRootLogin = "no";
      };
    };
  })

  (lib.mkIf f.networkTools {
    environment.systemPackages = with pkgs; [
      # Ferramentas básicas de rede
      iproute2
      inetutils

      # Diagnóstico
      traceroute
      mtr
      nmap
      netcat-openbsd
      tcpdump
      wireshark
      iperf3
      ethtool
      socat

      # DNS
      bind

      # Whois
      whois

      # HTTP
      curl
      wget

      # SSH
      openssh
    ];

    # Permite usar Wireshark sem root
    programs.wireshark = {
      enable = true;
      package = pkgs.wireshark;
    };
  })
]
