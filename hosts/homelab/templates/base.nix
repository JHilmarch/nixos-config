{ config, pkgs, modulesPath, lib, system, self, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    "${self}/modules/defaults.nix"
  ];

  networking.hostName = lib.mkDefault "base";

  boot = {
    growPartition = true;

    loader = {
      grub = {
        enable = true;
        device = "nodev";
      };
    };
  };

  nix = {
    settings = {
      trusted-users = [ "root" "@wheel" ];
      accept-flake-config = true;
      auto-optimise-store = false;
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  environment = {
    systemPackages = with pkgs; [
      vim
      git
    ];
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  services = {
    qemuGuest.enable = true;
    openssh = {
      enable = true;
      settings.PasswordAuthentication = lib.mkDefault false;
      settings.KbdInteractiveAuthentication = lib.mkDefault false;
    };
    avahi = {
        enable = true;
        nssmdns = true;
        publish = {
          enable = true;
          addresses = true;
        };
    };
  };

  programs = {
    ssh.startAgent = true;
  };

  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    autoResize = true;
    fsType = "ext4";
  };

  system.stateVersion = lib.mkDefault "25.05";
}
