{
  config,
  pkgs,
  username,
  inputs,
  self,
  ...
}: {
  imports = [
    "${self}/home-modules/fish"
    "${self}/home-modules/git/cab.nix"
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
      awesome-copilot
      unstable.playwright-mcp
      unstable.mcp-grafana
      unstable.mcp-proxy
      (dotnetCorePackages.combinePackages [
        dotnetCorePackages.dotnet_9.sdk
        dotnetCorePackages.dotnet_10.sdk
      ])
      unstable.nodejs_24
      local.context7-mcp
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
