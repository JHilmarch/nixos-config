{
  config,
  pkgs,
  username,
  inputs,
  self,
  ...
}: let
  unstable-packages = with pkgs.unstable; [
    jetbrains.rider # IDE for .NET and C# development
    nodejs_24
  ];

  llm-agents-packages = with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
    ck # Hybrid code search (semantic, lexical, regex)
  ];

  nix-auth-packages = with inputs.nix-auth.packages.${pkgs.stdenv.hostPlatform.system}; [
    nix-auth # Nix authentication tokens management
  ];

  stable-packages = with pkgs; [
    jetbrains.jdk # OpenJDK fork to better support Jetbrains's products
    git # A distributed version control system
    sops # Simple and flexible tool for managing secrets
    age # Modern encryption tool with small explicit keys
    age-plugin-yubikey # YubiKey plugin for age
    tree-sitter # A parser generator tool
    alejandra # nix linter
    pkgs.mdformat # CommonMark compliant Markdown formatter
    biome # Fast formatter/linter for JS, TS, JSON, CSS, HTML
    pinentry-tty # GnuPG's interface to passphrase input
    yubikey-manager # Command line tool for configuring any YubiKey over all USB transports
    yubico-piv-tool # Used for interacting with the Privilege and Identification Card (PIV) application on a YubiKey
    libfido2 # Provides library functionality for FIDO 2.0, including communication with a device over USB.
    fish-lsp # LSP implementation for the fish shell language
    grc # Generic text colouriser
    element-desktop # A feature-rich client for Matrix.org
    slack # Desktop client for Slack
    signal-desktop # Desktop client for Signal
    discord # All-in-one cross-platform voice and text chat for gamers
    gitleaks # Scan git repos (or files) for secrets
    vlc # Media player and streaming server
    _1password-gui # Password manager
    _1password-cli # 1Password command-line tool
    gnomeExtensions.tiling-shell # Tiling window manager
    wmctrl
    gnome-calendar
    gnome-terminal
    gnome-system-monitor
    geary # Mail client for GNOME 3
    lm_sensors # Tools for reading hardware sensors
    pv # Tool for monitoring the progress of data through a pipeline
    nssTools # Set of libraries for development of security-enabled client and server applications
    p11-kit # Library and tools for PKCS#11 modules and trust store
    openssl # Cryptographic library that implements the SSL and TLS protocols

    # Core functionality needed to create .NET Core projects
    (dotnetCorePackages.combinePackages [
      dotnetCorePackages.dotnet_9.sdk
      dotnetCorePackages.dotnet_10.sdk
    ])

    nuget # NuGet CLI for managing .NET packages
    cryptsetup # LUKS for dm-crypt
    sbctl # Secure Boot key manager

    local.mcp-nuget # NuGet MCP Server
  ];

  firefoxDefaultMime = {
    "text/html" = ["org.mozilla.firefox.desktop"];
    "application/xhtml+xml" = ["org.mozilla.firefox.desktop"];
    "x-scheme-handler/http" = ["org.mozilla.firefox.desktop"];
    "x-scheme-handler/https" = ["org.mozilla.firefox.desktop"];
    "x-scheme-handler/about" = ["org.mozilla.firefox.desktop"];
    "x-scheme-handler/unknown" = ["org.mozilla.firefox.desktop"];
  };
in {
  imports = [
    "${self}/home-modules/fish/dev.nix"
    "${self}/home-modules/gpg"
    "${self}/home-modules/ssh"
    "${self}/home-modules/git/ssh.nix"
    "${self}/home-modules/git/hooks.nix"
    "${self}/home-modules/claude"
    "${self}/home-modules/copilot-cli"
    "${self}/home-modules/opencode"
    inputs.nix-index-database.homeModules.nix-index
  ];

  home = {
    stateVersion = "26.05"; # https://nix-community.github.io/home-manager/
    username = "${username}";
    homeDirectory = "/home/${username}";
    sessionVariables = {
      EDITOR = "vim";
      MOZ_ENABLE_WAYLAND = "1";
    };

    packages =
      stable-packages
      ++ unstable-packages
      ++ llm-agents-packages
      ++ nix-auth-packages;
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

    starship.enable = true;
  };

  xdg = {
    mimeApps = {
      enable = true;
      defaultApplications = firefoxDefaultMime;
      associations.added = firefoxDefaultMime;
    };
  };
}
