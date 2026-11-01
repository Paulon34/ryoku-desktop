{ pkgs, ... }:

{
  programs.git = {
    enable = true;

    settings = {
      # user.name / user.email are personal: set them in the host's
      # ryoku.user.homeModules (ryoku-bootstrap writes hosts/<name>/home.nix).
      init.defaultBranch = "main";

      pull.rebase = false;

      push.autoSetupRemote = true;

      core.editor = "nvim";

      color.ui = true;

      alias = {
        st = "status";
        co = "checkout";
        br = "branch";
        ci = "commit";
        lg = "log --graph --decorate --oneline --all";
      };

      credential.helper = "!${pkgs.gh}/bin/gh auth git-credential";

      # What `git lfs install` writes; git-lfs itself comes from
      # modules/development.nix. Without the smudge filter, checkouts leave
      # LFS pointer files in assets/wallpapers and the flake copies those.
      filter.lfs = {
        clean = "git-lfs clean -- %f";
        smudge = "git-lfs smudge -- %f";
        process = "git-lfs filter-process";
        required = true;
      };
    };
  };
}
