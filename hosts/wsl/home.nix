{
  pkgs,
  username,
  ...
}: let
  unstable-packages = with pkgs.unstable; [
    coreutils # A collection of basic file, shell, and text manipulation utilities. ls, cat, rm, cp...
    findutils # A set of tools for finding files and directories based on various criteria
    htop # An interactive process viewer for Unix systems
    killall # A command that sends a signal to all processes running a specified command
    curl # A command-line tool for transferring data with URLs. find, xargs, locate...
    wget # A command-line utility for downloading files from the web
    git # A distributed version control system
    jq # A lightweight and flexible command-line JSON processor
    zip # A utility for creating ZIP archives
    unzip # A utility for extracting files from ZIP archives
    vim # Vim the editor
  ];

  stable-packages = with pkgs; [
    # You can add plugins, change keymaps etc using (jeezyvim.nixvimExtend {})
    # https://github.com/LGUG2Z/JeezyVim#extending
    jeezyvim # JeezyVim is a declarative NeoVim configuration built with NixVim.
    gh # GitHub CLI

    tree-sitter

    alejandra # nix linter
  ];
in {
  imports = [
    ./modules/starship/default.nix
    ../../modules/gpg/default.nix
    ./modules/fish/default.nix
    ../../modules/ssh/default.nix
    ../../modules/git/default.nix
  ];

  home = {
    stateVersion = "24.11"; # https://nix-community.github.io/home-manager/
    username = "${username}";
    homeDirectory = "/home/${username}";
    sessionVariables.EDITOR = "nvim";
    sessionVariables.SHELL = "/etc/profiles/per-user/${username}/bin/fish";
  };

  home.packages =
    stable-packages
    ++ unstable-packages
    ++ [
      # pkgs.some-package
      # pkgs.unstable.some-other-package
    ];

  programs = {
    home-manager.enable = true;

    nix-index = {
      enable = true;
      enableFishIntegration = true;
    };

    fzf = {
      enable = true;
      enableFishIntegration = true;
    };

    lsd = {
      enable = true;
      enableAliases = true;
    };

    zoxide = {
      enable = true;
      enableFishIntegration = true;
    };

    broot = {
      enable = true;
      enableFishIntegration = true;
    };

    direnv = {
      enable = true;
    };
  };
}
