{
  username,
  hostname,
  pkgs,
  inputs,
  ...
}: {
  # Run `timedatectl list-timezones` to list timezones"
  time.timeZone = "Europe/Stockholm";

  networking.hostName = "${hostname}";

  programs.fish.enable = true;
  environment.pathsToLink = ["/share/fish"];
  environment.shells = [pkgs.fish];

  environment.enableAllTerminfo = true;

  environment.systemPackages = [
    pkgs.yubikey-manager
    pkgs.libfido2
    pkgs.gnupg
  ];

  services.pcscd.enable = true;

  services.udev = {
    enable = true;
    packages = [pkgs.yubikey-personalization];
    extraRules = ''
      SUBSYSTEM=="usb", MODE="0666"
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", TAG+="uaccess", MODE="0666"
    '';
  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-curses;
    settings = {
      default-cache-ttl = 600;
      max-cache-ttl = 7200;
    };
  };

  security.sudo.wheelNeedsPassword = false;

  services.openssh.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      # Uncomment the next line if you want to run docker without sudo
      # "docker"
    ];

    openssh.authorizedKeys.keys = [
    ];
  };

  home-manager.users.${username} = {
    imports = [
      ./home.nix
    ];
  };

  wsl = {
    enable = true;
    wslConf.automount.root = "/mnt";
    wslConf.interop.appendWindowsPath = false;
    wslConf.network.generateHosts = false;
    defaultUser = username;
    startMenuLaunchers = true;

    # Docker Desktop (needs to be installed)
    docker-desktop.enable = true;

    # ATTACH YUBIKEY TO WSL
    # In Windows Terminal: Run `usbipd list` to get the correct BUSID
    # In Windows Terminal, as a Windows Administrator:
    ## Run `usbipd bind 5-4` to bind the USB port, then it will auto-attach to WSL.
    usbip = {
      enable = true;
      autoAttach = ["5-4"];
    };
  };

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune.enable = true;
  };

  programs.nix-ld = {
    enable = true;
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

    nixPath = [
      "nixpkgs=${inputs.nixpkgs.outPath}"
      "nixos-config=/etc/nixos/configuration.nix"
      "/nix/var/nix/profiles/per-user/root/channels"
    ];

    package = pkgs.nixVersions.stable;
    extraOptions = ''experimental-features = nix-command flakes'';

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  system.stateVersion = "24.11";
}
