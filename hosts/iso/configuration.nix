{
  config,
  pkgs,
  username,
  hostname,
  lib,
  system,
  self,
  ...
}: {
  imports = [
    "${self}/modules/defaults.nix"
  ];

  console.keyMap = "sv-latin1";

  networking = {
    hostName = "nixos-${hostname}";
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = lib.mkForce ["btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ntfs" "cifs"];
    loader = {
      grub.enable = false;
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    initrd = {
      availableKernelModules = [
        "vmd"
        "xhci_pci"
        "ahci"
        "nvme"
        "usbhid"
        "hid"
        "hid_generic"
        "usb_storage"
        "uas"
        "sd_mod"
      ];

      supportedFilesystems = ["nfs"];
      kernelModules = [
        "nfs"
        "vmd"
        "xhci_pci"
        "ahci"
        "nvme"
        "usbhid"
        "hid"
        "hid_generic"
        "usb_storage"
        "uas"
        "sd_mod"
      ];
    };

    kernelModules = ["kvm-intel" "btusb" "btintel"];
    extraModulePackages = [];
  };

  isoImage = {
    isoName = lib.mkForce "${username}-nixos-${config.system.stateVersion}-${system}.iso";
    contents = [
      {
        source = ./installation-guidelines.md;
        target = "README.md";
      }
    ];
  };

  environment.systemPackages = with pkgs; [
    util-linux
    cryptsetup
    git
  ];

  services = {
    openssh.enable = lib.mkForce false;
  };

  hardware = {
    enableAllFirmware = true;
    enableRedistributableFirmware = true;
    graphics.enable = false;
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  system.stateVersion = "24.11";
}
