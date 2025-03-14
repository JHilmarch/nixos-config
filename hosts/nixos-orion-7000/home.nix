{
  pkgs,
  username,
  inputs,
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
  ];

  stable-packages = with pkgs; [
    gh # GitHub CLI
    tree-sitter
    alejandra # nix linter
    pinentry-gnome3
    jetbrains.rider
    jetbrains.webstorm
  ];
in {
  imports = [
    ../../modules/gpg/default.nix
    ../../modules/ssh/default.nix
    ../../modules/git/default.nix
  ];

  home = {
    stateVersion = "24.11"; # https://nix-community.github.io/home-manager/
    username = "${username}";
    homeDirectory = "/home/${username}";
    sessionVariables.EDITOR = "vim";
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

    fzf = {
      enable = true;
      enableBashIntegration = true;
    };

    lsd = {
      enable = true;
      enableAliases = true;
    };

    zoxide = {
      enable = true;
      enableBashIntegration = true;
    };

    broot = {
      enable = true;
      enableBashIntegration = true;
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };

  services = {
    gpg-agent = {
      enable = true;
      pinentryPackage = pkgs.pinentry-gnome3;
    };
  };
}
