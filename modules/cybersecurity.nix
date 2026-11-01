{ config, lib, pkgs, ... }:

lib.mkIf config.ryoku.features.cybersecurity {
  environment.systemPackages = with pkgs; [
    # Recon / discovery
    nmap
    masscan
    amass

    # Web enumeration
    ffuf
    gobuster
    feroxbuster
    nikto

    # Web security
    burpsuite
    zap
    sqlmap

    # Password / hashes
    john
    hashcat

    # Network analysis
    wireshark
    tcpdump

    # Exploitation / labs
    metasploit

    # Utilities
    openssl
    gnupg
    curl
    jq
  ];

}
