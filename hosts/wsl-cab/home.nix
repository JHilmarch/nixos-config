{
  config,
  pkgs,
  username,
  inputs,
  self,
  ...
}: {
  imports = [
    "${self}/home-modules/fish/dev.nix"
    "${self}/home-modules/git/cab-ssh.nix"
    "${self}/home-modules/git/hooks.nix"
    "${self}/home-modules/ssh/cab.nix"
    "${self}/home-modules/copilot-cli"
    ./modules/copilot-cli.nix
  ];

  home = {
    stateVersion = "25.05";
    username = username;
    homeDirectory = "/home/${username}";
    sessionVariables = {
      EDITOR = "vim";
      BROWSER = "wslview";
    };

    packages = with pkgs; [
      git
      gh
      openssl
      tree-sitter
      pinentry-tty
      grc
      gitleaks
      nuget
      unstable.playwright-mcp
      unstable.mcp-proxy
      unstable.jetbrains.rider
      jetbrains.jdk
      (dotnetCorePackages.combinePackages [
        dotnetCorePackages.dotnet_9.sdk
        dotnetCorePackages.dotnet_10.sdk
      ])
      unstable.nodejs_24
      local.azure-devops-mcp
      wslu
      (symlinkJoin {
        name = "wsl-browser-wrappers";
        paths = [
          (writeShellScriptBin "xdg-open" ''exec ${wslu}/bin/wslview "$@"'')
          (writeShellScriptBin "x-www-browser" ''exec ${wslu}/bin/wslview "$@"'')
          (writeShellScriptBin "www-browser" ''exec ${wslu}/bin/wslview "$@"'')
        ];
      })
    ];
  };

  services.ssh-agent.enable = true;

  programs = {
    home-manager.enable = true;

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
      settings = {
        scan_timeout = 5000;
      };
    };
  };
}
