{
  config,
  pkgs,
  hostname,
  lib,
  username,
  inputs,
  functions,
  self,
  ...
}: let
  authorizedSSHKeys = functions.ssh.getGithubKeys {
    username = "JHilmarch";
    sha256 = "1zxj95jlhabgbaxvvhlhwvxlr6xn00ldx6yaz3sdga55wbcnsw34";
  };
in {
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p51
    ./modules/sops.nix
    ./modules/claude.nix
    ./modules/copilot-cli.nix
    ./modules/opencode.nix
    "${self}/modules/systemd/flatpak.nix"
    "${self}/modules/systemd/firefox.nix"
    "${self}/templates/desktop.nix"
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

  hardware = {
    enableAllFirmware = true;
    enableRedistributableFirmware = true;
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    bluetooth = {
      enable = true;
      powerOnBoot = false;
      settings = {
        General = {
          Name = "NixOS-P51-Bluetooth";
          ControllerMode = "dual";
          FastConnectable = true;
          Experimental = true;
        };
        Policy = {
          AutoEnable = true;
        };
      };
    };
    cpu.intel.updateMicrocode = true;
  };

  boot = {
    supportedFilesystems = ["ntfs" "vfat" "btrfs"];
    loader = {
      systemd-boot = {
        enable = true;
        editor = false;
      };
      efi.canTouchEfiVariables = true;
    };

    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usbhid"
        "hid_generic"
        "usb_storage"
        "uas"
        "sd_mod"
        "btrfs"
        "rtsx_pci_sdmmc" # SD card reader for P51
      ];
      supportedFilesystems = ["vfat" "btrfs"];
      kernelModules = ["vfat" "btrfs"];
      luks = {
        devices."encrypted-nix-root" = {
          device = "/dev/disk/by-uuid/d0814586-a92b-4f99-8cae-b495e7a483fa";
          crypttabExtraOpts = ["fido2-device=auto"];
        };
      };

      systemd = {
        enable = true;
        initrdBin = with pkgs; [
          cryptsetup # LUKS for dm-crypt
          gnused # GNU sed, a batch stream editor
          gawk # GNU implementation of the Awk programming language
        ];
      };
    };

    kernelModules = ["kvm-intel" "btusb" "btintel" "coretemp"];
    extraModulePackages = [];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXROOT";
      fsType = "btrfs";
      options = ["x-systemd.device-timeout=480s"];
    };

    "/boot" = {
      device = "/dev/disk/by-label/ESP";
      fsType = "vfat";
      options = ["fmask=0077" "dmask=0077"];
    };
  };

  swapDevices = [];

  networking = {
    hostName = "${hostname}";
    networkmanager.enable = true;
    useDHCP = false;
    firewall.enable = true;
  };

  environment = {
    enableAllTerminfo = true;

    systemPackages = with pkgs; [
      util-linux # Set of system utilities for Linux
      ripgrep # Utility that combines the usability of The Silver Searcher with the raw speed of grep
      pipewire # Server and user space API to deal with multimedia pipelines
      bluez # Official Linux Bluetooth protocol stack
      usbutils # Tools for working with USB devices, such as lsusb
      pciutils # Collection of programs for inspecting and manipulating configuration of PCI devices
      linuxKernel.packages.linux_zen.usbip # Allows to pass USB device from server to client over the network
      findutils # A set of tools for finding files and directories based on various criteria
      htop # An interactive process viewer for Unix systems
      killall # A command that sends a signal to all processes running a specified command
      curl # A command-line tool for transferring data with URLs. find, xargs, locate...
      wget # A command-line utility for downloading files from the web
      jq # A lightweight and flexible command-line JSON processor
      zip # A utility for creating ZIP archives
      unzip # A utility for extracting files from ZIP archives
      inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.mcp-nixos # MCP-NixOS
      flatpak # Linux application sandboxing and distribution framework
    ];

    gnome.excludePackages = with pkgs; [
      gnome-music
      gnome-tour
      totem
      yelp
      geary
    ];
  };

  services = {
    throttled.enable = true;

    pcscd = {
      enable = true;
      plugins = [pkgs.ccid]; # CCID IFD handler required for YubiKey PIV access
    };
    upower.enable = true;

    gvfs.enable = true;

    xserver = {
      enable = true;
      xkb.layout = "se";
    };

    desktopManager.gnome.enable = true;

    displayManager = {
      gdm = {
        enable = true;
        autoSuspend = false;
      };
      defaultSession = "gnome";
      autoLogin.enable = false;
    };

    udev = {
      enable = true;
      packages = [pkgs.yubikey-personalization];
      extraRules = ''
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1050", TAG+="uaccess", MODE="0660", GROUP="usbusers"
      '';
    };

    openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        Banner = builtins.toString (pkgs.writeText "sshd-banner" ''
          ${username}@${hostname}, log in with your SSH key (YubiKey)!
        '');
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
    };

    printing.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    systemdFlatpak.enable = true;
    systemdFirefox.enable = true;
  };

  programs = {
    _1password-gui = {
      enable = true;
      polkitPolicyOwners = ["${username}"];
    };
  };

  security = {
    rtkit.enable = true;
  };

  users = {
    groups.usbusers = {};
    users.${username} = {
      extraGroups = [
        "video"
        "audio"
        "usbusers"
      ];
      packages = with pkgs; [
        tree
      ];
      openssh.authorizedKeys.keys = authorizedSSHKeys;
    };
  };

  nix = {
    settings = {
      trusted-users = [username];
      accept-flake-config = true;
      auto-optimise-store = false;
      substituters = [
        "https://cache.nixos.org"
        "https://cache.numtide.com"
        "https://nix-community.cachix.org"
        "https://nixos.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        "nix-community.cachix.org-1:mB9FSh8qf2dCimDSUo8Zy7bkj5CX+/rkCWyvRCYg3Fs="
        "nixos.cachix.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    };

    registry = {
      nixpkgs = {
        flake = inputs.nixpkgs;
      };
    };

    package = pkgs.nixVersions.stable;

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  fonts.packages = with pkgs; [
    corefonts
  ];

  system.stateVersion = "26.05";
}
