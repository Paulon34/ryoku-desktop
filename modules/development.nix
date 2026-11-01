{ config, lib, pkgs, ... }:

lib.mkIf config.ryoku.features.development {
  environment.systemPackages = with pkgs; [
    # Editores
    vscode
    neovim

    # Git / GitHub
    git
    git-lfs
    gh
    lazygit

    # Python
    python3
    python3Packages.pip
    pipx

    # Java
    jdk21

    # JavaScript / TypeScript
    nodejs
    pnpm
    yarn

    # C / C++
    gcc
    clang
    clang-tools
    gdb
    cmake
    ninja
    gnumake

    # Rust
    rustc
    cargo
    rustfmt
    clippy

    # Go
    go
    gopls

    # Bancos / dados
    sqlite
    postgresql
    mysql84

    # APIs / HTTP
    httpie
    postman

    # Ferramentas úteis
    codex
    direnv
    nix-direnv
    just
    shellcheck
    shfmt

    # JSON / YAML
    jq
    yq-go
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
