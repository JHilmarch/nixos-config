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
    ];
  };

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
