{
  config,
  pkgs,
  lib,
  username,
  inputs,
  self,
  functions,
  ...
}: let
  authorizedSSHKeys = functions.ssh.getGithubKeys {
    username = "JHilmarch";
    sha256 = "be8166d2e49794c8e2fb64a6868e55249b4f2dd7cd8ecf1e40e0323fb12a2348";
  };
in {
  imports = [
    "${self}/modules/defaults.nix"
    "${self}/modules/markitdown-mcp/default.nix"
    "${self}/hosts/wsl-cab/modules/systemd/prepare-ssh-key.nix"
    "${self}/hosts/wsl-cab/modules/systemd/decrypt-secrets.nix"
  ];

  networking.hostName = "wsl-cab";

  nixpkgs = {
    overlays = [
      (_final: prev: {
        unstable = import inputs.nixpkgs-unstable {
          system = prev.stdenv.hostPlatform.system;
          config = prev.config;
        };
      })
      (import ./../../overlays/awesome-copilot)
      (import ./../../overlays/nuget-mcp-server)
      (import ./../../overlays/azure-mcp-server)
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

    openssh = {
      authorizedKeys.keys =
        authorizedSSHKeys
        ++ [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFlzuRfJ6DYs7aTGgRxujw4d0z3klTszPQIbnyIrf0dN jonatan@wsl-cab"
        ];
    };
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

  services = {
    markitdown-mcp.enable = true;
    pcscd.enable = true;

    prepare-ssh-key = {
      enable = true;
    };

    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
    };

    decrypt-secrets = {
      enable = true;
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
        pkgs.python313Packages.markitdown
        azure-mcp-server
      ];
    in
      base ++ lib.optional (pkgs ? mcp-nuget) pkgs.mcp-nuget;

    shells = with pkgs; [fish bash];

    etc = {
      "nixos/secrets/wsl-cab/secrets.yml".source = "${self}/secrets/${config.networking.hostName}/secrets.yml";
    };
  };

  system.stateVersion = "25.05";
}
