{
  config,
  pkgs,
  hostname,
  lib,
  username,
  inputs,
  ...
}:
let
  ports = {
    # Discover Google Cast and other Spotify Connect devices (TCP)
    spotify-localDiscovery-casting = 5353;
    # Sync local tracks with mobile in the same network (TCP+UDP)
    spotify-localDiscovery-mobileSync = 57621;

    fileSystem-nfs4-nfsdService = 2049; # (TCP)
  };

  udpPorts = [
    ports.spotify-localDiscovery-mobileSync
  ];

  tcpOnlyPorts = builtins.filter (port: !builtins.elem port udpPorts) (builtins.attrValues ports);

  firewallOptions = {
    allowedPorts = {
      udp = udpPorts;
      tcp = tcpOnlyPorts ++ [ ports.spotify-localDiscovery-mobileSync ];
    };
  };

  nfsShareOptions = [
    "nfsvers=4"
    "x-systemd.automount"
    "noauto"
  ];

  # TODO: create mount points on boot, if not exist.
  fileshareOptions = {
    mountSharePath = "/mnt/FILESHARE_SHARE";
    mountJonatanArkivPath = "/mnt/FILESHARE_JONATAN_ARKIV";
  };
in
{

  imports = [
    ./modules/sops.nix
  ];

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
      supportedFilesystems = [ "nfs" ];
      kernelModules = [ "nfs" ];
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

  fileSystems."${fileshareOptions.mountSharePath}" = {
    device = "fileshare.local:/volume2/SHARE";
    fsType = "nfs";
    options = nfsShareOptions;
  };

  fileSystems."${fileshareOptions.mountJonatanArkivPath}" = {
    device = "fileshare.local:/volume2/Jonatan arkiv";
    fsType = "nfs";
    options = nfsShareOptions;
  };

  networking = {
    hostName = "${hostname}";
    networkmanager.enable = true;

    firewall = {
      enable = true;

      allowedTCPPorts = firewallOptions.allowedPorts.tcp;
      allowedUDPPorts = firewallOptions.allowedPorts.udp;
    };

    hosts = {
      "192.168.2.103" = ["fileshare.local"];
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
      geary # Mail client for GNOME 3
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
