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
    ./modules/sops.nix
    ./modules/docker.nix
    ./modules/openrazer.nix
    ./modules/claude.nix
    "${self}/modules/context7/sops-wrapper.nix"
    "${self}/modules/markitdown-mcp/default.nix"
    "${self}/modules/nfs/fileshare.nix"
    "${self}/modules/systemd/no-sleep.nix"
    "${self}/modules/systemd/wake-on-lan.nix"
    "${self}/modules/systemd/flatpak.nix"
    "${self}/modules/systemd/mullvad-browser.nix"
    "${self}/modules/systemd/firefox.nix"
    "${self}/modules/systemd/nvidia-coolbits.nix"
    "${self}/modules/systemd/power-profile.nix"
    "${self}/modules/spotify/firewall.nix"
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
      (_final: prev: {
        pinned = import inputs.nixpkgs-pinned {
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
    graphics.enable = true;
    nvidia = {
      open = true;
      nvidiaSettings = true;
    };
    bluetooth = {
      enable = true;
      powerOnBoot = false;
      settings = {
        General = {
          Name = "NixOS-Orion-7000-Bluetooth";
          ControllerMode = "dual";
          FastConnectable = true;
          Experimental = true;
        };
        Policy = {
          AutoEnable = true;
        };
      };
    };
    openrazer.enable = true;
    openrazer.users = ["${username}"];
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
      # check with command 'lspci -v'
      availableKernelModules = [
        "vmd"
        "xhci_pci"
        "ahci"
        "nvme"
        "usbhid"
        "hid_generic"
        "usb_storage"
        "uas"
        "sd_mod"
        "btrfs"
        "r8169"
        "vhci_hcd"
      ];
      supportedFilesystems = ["nfs" "vfat"];
      kernelModules = ["nfs" "vfat" "btrfs"];
      luks = {
        devices."encrypted-nix-root" = {
          device = "/dev/disk/by-uuid/e8bb294d-bba0-43f5-936d-4fcc08aa6ce7";
          crypttabExtraOpts = ["fido2-device=auto"];
        };
      };
      systemd = {
        enable = true;
        initrdBin = with pkgs; [
          cryptsetup # LUKS for dm-crypt
          linuxKernel.packages.linux_zen.usbip # allows to pass USB device from server to client over the network
          gnused # GNU sed, a batch stream editor
          gawk # GNU implementation of the Awk programming language
          (pkgs.writeShellScriptBin "init-shell" (builtins.readFile ./boot-initrd-scripts/init-shell.sh))
          (pkgs.writeShellScriptBin "attach-yubikey" (builtins.readFile ./boot-initrd-scripts/attach-yubikey.sh))
          (pkgs.writeShellScriptBin "detach-yubikey" (builtins.readFile ./boot-initrd-scripts/detach-yubikey.sh))
          (pkgs.writeShellScriptBin "unlock" (builtins.readFile ./boot-initrd-scripts/unlock-luks.sh))
        ];

        network = {
          enable = true;
          wait-online.enable = false;
          networks.enp6s0 = {
            matchConfig.Name = "enp6s0";
            networkConfig.DHCP = "yes";
          };
        };

        users.root.shell = "/bin/init-shell";
      };

      network = {
        enable = true;
        ssh = {
          enable = true;
          authorizedKeys = authorizedSSHKeys;
          hostKeys = ["/etc/ssh/initrd_ssh_host_ed25519_key"];
        };
      };
    };

    kernelModules = ["kvm-intel" "btusb" "btintel" "coretemp" "nct6775"];
    extraModulePackages = [];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXROOT";
    fsType = "btrfs";
    options = ["x-systemd.device-timeout=480s"];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };

  swapDevices = [
  ];

  fileSystems."/mnt/samsung-ssd-870-evo-1tb-usb" = {
    device = "/dev/disk/by-label/samsung-ssd-870-evo-1tb-usb";
    fsType = "ntfs";
  };

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
      icu # libicu runtime for .NET/globalization (no 'icu' binary expected)
      azure-cli # Microsoft Azure CLI
      inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.mcp-nixos # MCP-NixOS
      pkgs.python313Packages.markitdown # Markdown to other formats converter
      flatpak # Linux application sandboxing and distribution framework

      # Remote Desktop Server packages
      gnome-remote-desktop # GNOME Remote Desktop server
      gnome-session # GNOME session manager
      xrdp # Open source RDP server
    ];

    gnome.excludePackages = with pkgs; [
      # evince # document viewer
      # gnome-characters

      epiphany # web browser
      # geary # email reader
      gnome-music # music player
      gnome-tour # GNOME Greeter & Tour
      totem # video player
      yelp # Help view
      geary # Mail client for GNOME 3
    ];
  };

  services = {
    # Enable PCSC-Lite daemon, to access smart cards using SCard API (PC/SC).
    pcscd.enable = true;

    # UPower D-Bus service for power management
    upower.enable = true;

    # markitdown-mcp native Python package (installed via Nix, runs on-demand for stdio)
    markitdown-mcp.enable = true;

    # Power Profiles Daemon for power management
    power-profiles-daemon.enable = true;

    # GVFS provides virtual filesystem backends used by GNOME apps and Flatpaks
    gvfs.enable = true;

    # X11 windowing system
    xserver = {
      enable = true;
      xkb.layout = "se";
      videoDrivers = ["nvidia"];
    };

    # Desktop and Display Managers
    desktopManager.gnome.enable = true;

    displayManager = {
      gdm = {
        enable = true;
        autoSuspend = false;
      };
      defaultSession = "gnome";
      autoLogin.enable = false;
    };

    gnome = {
      gnome-remote-desktop.enable = true;
    };

    xrdp = {
      enable = true;
      defaultWindowManager = "gnome-session";
      openFirewall = true;
    };

    udev = {
      enable = true;
      packages = [pkgs.yubikey-personalization];
      extraRules = ''
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", MODE="0660", GROUP="usbusers"
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", TAG+="uaccess", MODE="0660", GROUP="usbusers"
      '';
    };

    openssh = {
      enable = true;
      banner = "${username}@${hostname}, log in with your SSH key (YubiKey)!";
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
    };

    # Enable CUPS to print documents.
    printing.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    systemdNoSleep.enable = true;
    systemdWakeOnLan.enable = true;
    spotifyFirewall.enable = true;
    systemdFlatpak.enable = true;
    systemdMullvadBrowser.enable = true;
    systemdFirefox.enable = true;
    systemdNvidiaCoolbits.enable = true;
    systemdPowerProfile.enable = true;
  };

  programs = {
    _1password-gui = {
      enable = true;
      # Certain features, including CLI integration and system authentication support,
      # require enabling PolKit integration on some desktop environments (e.g. Plasma).
      polkitPolicyOwners = ["${username}"];
    };

    coolercontrol = {
      enable = true;
    };
  };

  security = {
    rtkit.enable = true;
    pki.certificateFiles = [
      "${self}/hosts/orion/aspnetcore-https-development.pem"
    ];
  };

  users = {
    groups.usbusers = {};
    users.${username} = {
      extraGroups = [
        "docker"
        "openrazer"
        "video"
        "audio"
        "usbusers"
      ];
      packages = with pkgs; [
        tree
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPhXKd/Bp3e0yFS8WU2v2ul4/2nsWSQOoLdYVJWPPHWn jonatan@nixos-orion"
      ];
    };
  };

  nix = {
    settings = {
      trusted-users = [username];
      accept-flake-config = true;
      auto-optimise-store = false;
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

  system.stateVersion = "24.11";
}
