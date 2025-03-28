{
  config,
  hostname,
  lib,
  username,
  pkgs,
  inputs,
  ...
}: {

  # Run `timedatectl list-timezones` to list timezones"
  time.timeZone = "Europe/Stockholm";

  hardware = {
    enableAllFirmware = true;
    enableRedistributableFirmware = true;
    graphics.enable = true;
    nvidia.open = true;
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
  };

  boot = {
    supportedFilesystems = [ "ntfs" ];
    loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
    };

    initrd = {
      availableKernelModules = [ "vmd" "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "uas" "sd_mod" ];
      kernelModules = [ ];
    };

    kernelModules = [ "kvm-intel" "btusb" "btintel" ];
    extraModulePackages = [ ];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXROOT";
    fsType = "btrfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  swapDevices = [
    { device = "/dev/disk/by-label/NIXSWAP"; }
  ];

  fileSystems."/mnt/samsung-ssd-870-evo-1tb-usb" = {
    device = "/dev/disk/by-label/samsung-ssd-870-evo-1tb-usb";
    fsType = "ntfs";
  };

  networking = {
    hostName = "${hostname}";
    networkmanager.enable = true;

    firewall = {
      enable = true;

      # Local discovery for Spotify Connect
      allowedTCPPorts = [ 57621 ];
      allowedUDPPorts = [ 5353 ];
    };
  };

  environment = {

    enableAllTerminfo = true;

    systemPackages = with pkgs; [
      vim
      util-linux
      ripgrep
      pipewire
      bluez
      usbutils
      pciutils
    ];

    gnome.excludePackages = (with pkgs; [
      # evince # document viewer
      # gnome-characters

      epiphany # web browser
      # geary # email reader
      gnome-music # music player
      gnome-tour # GNOME Greeter & Tour
      totem # video player
      yelp # Help view
    ]);

    shells = [ pkgs.fish ];
  };

  services = {

    # Enable PCSC-Lite daemon, to access smart cards using SCard API (PC/SC).
    pcscd.enable = true;

    # X11 windowing system
    xserver = {
      enable = true;
      xkb.layout = "se";

      # Enable the GNOME Desktop Environment.
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;

      videoDrivers = [ "nvidia" ];
    };

    udev = {
      enable = true;
      packages = [pkgs.yubikey-personalization];
    };

    openssh.enable = true;

    # Enable CUPS to print documents.
    printing.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };

  programs = {
    fish.enable = true;
    nix-ld = {
      enable = true;
    };

    _1password-gui = {
      enable = true;
      # Certain features, including CLI integration and system authentication support,
      # require enabling PolKit integration on some desktop environments (e.g. Plasma).
      polkitPolicyOwners = [ "${username}" ];
    };
  };

  security = {
    sudo.wheelNeedsPassword = true;
    rtkit.enable = true;
  };

  users.defaultUserShell = pkgs.fish;
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    packages = with pkgs; [
      tree
    ];

    openssh.authorizedKeys.keys = [
    ];
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
    extraOptions = ''experimental-features = nix-command flakes'';

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
