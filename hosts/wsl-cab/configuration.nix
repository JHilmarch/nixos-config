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
    "${self}/modules/markitdown-mcp/default.nix"
  ];

  nixpkgs = {
    overlays = [
      (_final: prev: {
        unstable = import inputs.nixpkgs-unstable {
          inherit (prev.stdenv.hostPlatform) system;
          config = prev.config;
        };
      })
      (import ./../../overlays/context7)
      (import ./../../overlays/awesome-copilot)
      (import ./../../overlays/nuget-mcp-server)
      (import ./../../overlays/azure-mcp-server)
      (import ./../../overlays/github-mcp-server/gh-cli.nix)
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
        context7
        azure-mcp-server
        github-mcp-server
      ];
    in
      base ++ lib.optional (pkgs ? mcp-nuget) pkgs.mcp-nuget;

    shells = with pkgs; [fish bash];
  };

  system.stateVersion = "25.05";
}
