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
    ./modules/copilot-cli.nix
  ];

  nixpkgs = {
    overlays = [
      (_final: prev: {
        unstable = import inputs.nixpkgs-unstable {
          system = prev.stdenv.hostPlatform.system;
          config = prev.config;
        };
      })
    ];
    config = {
      allowUnfree = true;
    };
  };

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
      enable = false;
      setSocketVariable = true;
    };
  };

  programs = {
    fish.enable = true;
    nix-ld.enable = true;
  };

  services.markitdown-mcp.enable = true;

  environment = {
    systemPackages = let
      base = with pkgs; [
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
        icu
        azure-cli
        inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.mcp-nixos
        pkgs.python313Packages.markitdown
        local.azure-mcp-server
        local.github-mcp-server
        local.mcp-nuget
      ];
    in
      base;

    shells = with pkgs; [fish bash];
  };

  system.stateVersion = "25.05";
}
