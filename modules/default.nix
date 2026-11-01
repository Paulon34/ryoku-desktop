{ ... }:

# nixosModules.ryoku — the reusable Ryoku desktop. Hosts import this together
# with Home Manager and nix-flatpak (see flake.nix `mkRyokuSystem`) and set the
# options in ./options.nix. Personal, machine-specific configuration lives in
# hosts/<name>/, never here.

{
  imports = [
    ./options.nix
    ./users.nix
    ./base.nix
    ./nix-maintenance.nix
    ./desktop.nix
    ./gaming.nix
    ./development.nix
    ./networking.nix
    ./cybersecurity.nix
    ./multimedia.nix
    ./printing.nix
    ./virtualization.nix
    ./services.nix
    ./flatpak.nix
    ./ryoku.nix
  ];
}
