{
  pkgs,
  username,
  inputs,
  self,
  ...
}: let
  unstable-packages = with pkgs.unstable; [

  ];

  stable-packages = with pkgs; [
    git # A distributed version control system
    gh # GitHub CLI
    sops # Simple and flexible tool for managing secrets
    age # Modern encryption tool with small explicit keys
    age-plugin-yubikey # YubiKey plugin for age
    bruno # Open-source IDE For exploring and testing APIs
    bruno-cli # CLI of the open-source IDE For exploring and testing APIs
    tree-sitter # A parser generator tool
    alejandra # nix linter
    pinentry-tty # GnuPG’s interface to passphrase input
    jetbrains.rider # IDE for .NET and C# development
    jetbrains.webstorm # IDE for Web Development
    yubikey-manager # Command line tool for configuring any YubiKey over all USB transports
    yubico-piv-tool # Used for interacting with the Privilege and Identification Card (PIV) application on a YubiKey
    libfido2 # Provides library functionality for FIDO 2.0, including communication with a device over USB.
    spotify
    firefox
    grc # Generic text colouriser
    element-desktop # A feature-rich client for Matrix.org
    slack # Desktop client for Slack
    signal-desktop # Desktop client for Signal
    discord # All-in-one cross-platform voice and text chat for gamers
    gitleaks # Scan git repos (or files) for secrets
    vlc # Media player and streaming server
    dconf-editor # GSettings editor for GNOME
    dconf2nix # Convert dconf files to Nix, as expected by Home Manager
    _1password-gui # Password manager
    gnomeExtensions.tiling-shell # Tiling window manager
    wmctrl
    gnome-calendar
    gnome-terminal
    gnome-system-monitor
    onlyoffice-desktopeditors # Office suite that combines text, spreadsheet and presentation editors
    geary # Mail client for GNOME 3
    openrazer-daemon # Entirely open source user-space daemon that allows you to manage your Razer peripherals
    polychromatic # Graphical front-end and tray applet for configuring Razer peripherals
    lm_sensors # Tools for reading hardware sensors

    cryptsetup # LUKS for dm-crypt
    dotnet-sdk_9 # Core functionality needed to create .NET Core projects
    sbctl # Secure Boot key manager

    # Monitor and control your cooling devices
    coolercontrol.coolercontrold
    coolercontrol.coolercontrol-ui-data
    coolercontrol.coolercontrol-liqctld
    coolercontrol.coolercontrol-gui
  ];
in {
  imports = [
    "${self}/home-modules/fish"
    "${self}/home-modules/gpg"
    "${self}/home-modules/ssh"
    "${self}/home-modules/git"
    ./modules/file.nix
    inputs.nix-index-database.hmModules.nix-index
    ./modules/dconf
  ];

  home = {
    stateVersion = "24.11"; # https://nix-community.github.io/home-manager/
    username = "${username}";
    homeDirectory = "/home/${username}";
    sessionVariables = {
      EDITOR = "vim";
    };

    packages =
      stable-packages
      ++ unstable-packages
      ++ [
        (pkgs.writeShellScriptBin "attach-yubikey" (builtins.readFile ./boot-initrd-scripts/attach-yubikey.sh))
        (pkgs.writeShellScriptBin "detach-yubikey" (builtins.readFile ./boot-initrd-scripts/detach-yubikey.sh))
        (pkgs.writeShellScriptBin "boot-windows" (builtins.readFile "${self}/scripts/reboot-to-windows.sh"))
      ];
  };

  programs = {
    home-manager.enable = true;

    nix-index-database = {
      comma.enable = true;
    };

    nix-index.enable = true;

    lsd = {
      enable = true;
      enableFishIntegration = config.programs.fish.enable;
    };

    fzf = {
      enable = true;
      enableFishIntegration = config.programs.fish.enable;
    };

    zoxide = {
      enable = true;
      enableFishIntegration = config.programs.fish.enable;
    };

    broot = {
      enable = true;
      enableFishIntegration = config.programs.fish.enable;
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    starship = {
      enable = true;
    };
  };
}
