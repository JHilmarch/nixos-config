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
      tree-sitter
      pinentry-tty
      grc
      gitleaks
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
    };
  };
}
