{
  pkgs,
  username,
  inputs,
  ...
}: let
  unstable-packages = with pkgs.unstable; [
    git # A distributed version control system
    gh # GitHub CLI
  ];

  stable-packages = with pkgs; [
    coreutils # A collection of basic file, shell, and text manipulation utilities. ls, cat, rm, cp...
    findutils # A set of tools for finding files and directories based on various criteria
    htop # An interactive process viewer for Unix systems
    killall # A command that sends a signal to all processes running a specified command
    curl # A command-line tool for transferring data with URLs. find, xargs, locate...
    wget # A command-line utility for downloading files from the web
    jq # A lightweight and flexible command-line JSON processor
    zip # A utility for creating ZIP archives
    unzip # A utility for extracting files from ZIP archives
    tree-sitter # A parser generator tool
    alejandra # nix linter
    pinentry-gnome3 # GnuPG’s interface to passphrase input in GNOME
    jetbrains.rider # IDE for .NET and C# development
    jetbrains.webstorm # IDE for Web Development
    yubikey-manager # Command line tool for configuring any YubiKey over all USB transports
    libfido2 # Provides library functionality for FIDO 2.0, including communication with a device over USB.
    spotify
    firefox
    grc # Generic text colouriser
  ];
in {
  imports = [
    ../../modules/fish/default.nix
    ../../modules/gpg/default.nix
    ../../modules/ssh/default.nix
    ../../modules/git/default.nix
    inputs.nix-index-database.hmModules.nix-index
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

    nix-index-database = {
      comma.enable = true;
    };

    nix-index.enable = true;

    lsd = {
      enable = true;
      enableAliases = true;
    };

    fzf = {
      enable = true;
      enableFishIntegration = true;
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
      nix-direnv.enable = true;
    };

    starship = {
      enable = true;
    };
  };

  services = {
    gpg-agent = {
      enable = true;
      pinentryPackage = pkgs.pinentry-gnome3;
    };
  };
}
