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
    jetbrains.webstorm # IDE for Web Development
    playwright-mcp # Playwright MCP server
    mcp-proxy # MCP server which proxies other MCP servers from stdio to SSE or from SSE to stdio
    nodejs_24
    codeql # Semantic code analysis engine for security research and vulnerability detection
  ];

  llm-agents-packages = with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
    ck # Hybrid code search (semantic, lexical, regex)
  ];

  stable-packages = with pkgs; [
    jetbrains.jdk # OpenJDK fork to better support Jetbrains's products
    git # A distributed version control system
    sops # Simple and flexible tool for managing secrets
    age # Modern encryption tool with small explicit keys
    age-plugin-yubikey # YubiKey plugin for age
    bruno # Open-source IDE For exploring and testing APIs
    bruno-cli # CLI of the open-source IDE For exploring and testing APIs
    tree-sitter # A parser generator tool
    alejandra # nix linter
    pkgs.mdformat # CommonMark compliant Markdown formatter
    pinentry-tty # GnuPG’s interface to passphrase input
    yubikey-manager # Command line tool for configuring any YubiKey over all USB transports
    yubico-piv-tool # Used for interacting with the Privilege and Identification Card (PIV) application on a YubiKey
    libfido2 # Provides library functionality for FIDO 2.0, including communication with a device over USB.
    spotify
    fish-lsp # LSP implementation for the fish shell language
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
    _1password-cli # 1Password command-line tool
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
    nuget # NuGet CLI for managing .NET packages
    cryptsetup # LUKS for dm-crypt
    nssTools # Set of libraries for development of security-enabled client and server applications
    p11-kit # Library and tools for PKCS#11 modules and trust store
    openssl # Cryptographic library that implements the SSL and TLS protocols

    # Core functionality needed to create .NET Core projects
    (dotnetCorePackages.combinePackages [
      dotnetCorePackages.dotnet_9.sdk
      dotnetCorePackages.dotnet_10.sdk
    ])

    sbctl # Secure Boot key manager

    # Monitor and control your cooling devices
    coolercontrol.coolercontrold
    coolercontrol.coolercontrol-ui-data
    coolercontrol.coolercontrol-gui

    local.context7-mcp # Context7 MCP CLI
    local.mcp-nuget # NuGet MCP Server
    local.github-personal-mcp # GitHub MCP Server for personal account
    local.github-work-mcp # GitHub MCP Server for work account
    local.gh-personal # GitHub CLI authenticated with PAT for the personal GitHub area
    local.gh-personal-project-manager # GitHub CLI authenticated with classic PAT for project management
    local.gh-work # GitHub CLI authenticated with PAT for the work GitHub area
    local.azure-mcp-server # Azure MCP CLI
    local.awesome-copilot-patched # Awesome Copilot MCP (with MCP logging patch)
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
    "${self}/home-modules/claude"
    "${self}/home-modules/xorg/allow-root.nix"
    ./modules/file.nix
    inputs.nix-index-database.homeModules.nix-index
    ./modules/dconf
  ];

  home = {
    stateVersion = "24.11"; # https://nix-community.github.io/home-manager/
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
      ++ [
        (pkgs.writeShellScriptBin "attach-yubikey" (builtins.readFile ./boot-initrd-scripts/attach-yubikey.sh))
        (pkgs.writeShellScriptBin "detach-yubikey" (builtins.readFile ./boot-initrd-scripts/detach-yubikey.sh))
        (pkgs.writeShellScriptBin "boot-windows" (builtins.readFile "${self}/scripts/reboot-to-windows.sh"))
      ];

    file.".config/monitors.xml".source = ./monitors.xml;
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
    xorgAllowRoot.enable = true;
  };

  xdg = {
    mimeApps = {
      enable = true;
      defaultApplications = firefoxDefaultMime;
      associations.added = firefoxDefaultMime;
    };
  };
}
