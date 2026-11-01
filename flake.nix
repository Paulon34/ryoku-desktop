{
  description = "Ryoku — a NixOS desktop with Hyprland, the DMS shell (Quattro/Islands), Material You and Ryoku Settings";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak/latest";
  };

  outputs = { self, nixpkgs, home-manager, nix-flatpak, ... }@inputs:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      pkgs = nixpkgs.legacyPackages.${system};
      ryokuLib = import ./ryoku/lib.nix { inherit lib; };

      # A Ryoku machine: the reusable core plus one host module.
      mkRyokuSystem = hostModules:
        lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            self.nixosModules.ryoku
            home-manager.nixosModules.home-manager
            nix-flatpak.nixosModules.nix-flatpak
          ] ++ hostModules;
        };

      # Every hosts/<name>/default.nix is a configuration .#<name>: hand-written
      # hosts and the ones written by scripts/ryoku-bootstrap both live there
      # (a new host must be `git add`ed before the flake can see it).
      hostNames = lib.optionals (builtins.pathExists ./hosts) (lib.attrNames (lib.filterAttrs
        (name: type: type == "directory" && builtins.pathExists (./hosts + "/${name}/default.nix"))
        (builtins.readDir ./hosts)));

      generic = profile: mkRyokuSystem [
        ./tests/hosts/generic.nix
        { ryoku.profile = profile; }
      ];
    in
    {
      # Lightweight hash for Ryoku Settings ApplyController (no full NixOS eval).
      # Usage: nix eval --raw .#ryokuSettingsHash
      ryokuSettingsHash = ryokuLib.settingsHash;

      nixosModules.ryoku = ./modules;
      nixosModules.default = self.nixosModules.ryoku;

      nixosConfigurations =
        lib.genAttrs hostNames (name: mkRyokuSystem [ (./hosts + "/${name}") ])
        // {
          # Machine-independent builds of both profiles (CI, VM test).
          ryoku-minimal = generic "minimal";
          ryoku-full = generic "full";
        };

      packages.${system} = {
        # Development build; the system installs its own copy with the repo
        # path and flake host baked in (modules/ryoku.nix).
        ryoku-settings = pkgs.callPackage ./pkgs/ryoku-settings.nix { };
        ryoku-video-wallpaper = pkgs.callPackage ./pkgs/ryoku-video-wallpaper.nix { };
        ryoku-bootstrap = pkgs.callPackage ./pkgs/ryoku-bootstrap.nix { };
        default = self.packages.${system}.ryoku-settings;
      };

      apps.${system}.bootstrap = {
        type = "app";
        program = lib.getExe self.packages.${system}.ryoku-bootstrap;
        meta.description = "Generate a reviewable Ryoku host for this NixOS machine (--dry-run to preview)";
      };

      checks.${system} = {
        bootstrap = pkgs.callPackage ./tests/bootstrap.nix {
          ryoku-bootstrap = self.packages.${system}.ryoku-bootstrap;
        };
      };

      # Boots ryoku-minimal in QEMU and checks the session stack (needs KVM;
      # kept out of `checks` so `nix flake check` works without it):
      #   nix build .#legacyPackages.x86_64-linux.vmTest
      legacyPackages.${system}.vmTest = import ./tests/vm.nix {
        inherit pkgs self inputs;
      };
    };
}
