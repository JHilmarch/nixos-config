{
  config,
  pkgs,
  lib,
  username,
  inputs,
  self,
  ...
}: {
  imports = [
    "${self}/modules/defaults.nix"
  ];

  wsl = {
    enable = true;
    defaultUser = username;
    docker-desktop.enable = false;
    wslConf = {
      interop.appendWindowsPath = false;
    };
  };

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = ["wheel" "docker"];
    initialHashedPassword = "";
    shell = pkgs.fish;
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
  };

  virtualisation.docker = {
    enable = true;
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

  programs.fish.enable = true;

  environment = {
    systemPackages = with pkgs; [
      vim
      util-linux
      ripgrep
      coreutils
      findutils
      killall
      curl
      wget
      jq
      zip
      unzip
      inputs.mcp-nixos.packages.${pkgs.system}.mcp-nixos
      context7
      mcp-nuget
      azure-mcp-server
      github-mcp-server
    ];

    shells = with pkgs; [fish bash];
  };

  system.stateVersion = "25.05";
}
