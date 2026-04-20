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
    linger = true;
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
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib
        zlib
        zstd
        curl
        openssl
        libxml2
        fontconfig
        freetype
        libxkbcommon
        xorg.libX11
        xorg.libXext
        xorg.libXrender
        xorg.libXi
        xorg.libXtst
        xorg.libXrandr
        xorg.libICE
        xorg.libSM
        libGL
        alsa-lib
        expat
      ];
    };
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
        AllowTcpForwarding = true;
      };
    };

    vscode-server = {
      enable = true;
      enableFHS = true;
    };
  };

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
      ];
    in
      base;

    shells = with pkgs; [fish bash];
  };

  system.stateVersion = "25.05";
}
