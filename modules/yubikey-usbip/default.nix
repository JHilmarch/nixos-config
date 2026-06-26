{
  config,
  lib,
  pkgs,
  self,
  ...
}: let
  cfg = config.services.yubikeyUsbip;
  scripts = "${self}/scripts/yubikey-usbip";
in {
  options.services.yubikeyUsbip = {
    enable = lib.mkEnableOption "YubiKey USB/IP forwarding scripts and device access (usbusers group + udev hidraw rules)";
  };

  config = lib.mkIf cfg.enable {
    # Group used by the udev rule below; add interactive users to it per-host.
    users.groups.usbusers = {};

    services.udev = {
      packages = [pkgs.yubikey-personalization];
      extraRules = ''
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1050", TAG+="uaccess", MODE="0660", GROUP="usbusers"
      '';
    };

    environment.systemPackages = [
      pkgs.linuxKernel.packages.linux_zen.usbip
      (pkgs.writeShellScriptBin "detect-yubikey" (builtins.readFile "${scripts}/detect-yubikey.sh"))
      (pkgs.writeShellScriptBin "bind-yubikey" (builtins.readFile "${scripts}/bind-yubikey.sh"))
      (pkgs.writeShellScriptBin "unbind-yubikey" (builtins.readFile "${scripts}/unbind-yubikey.sh"))
      (pkgs.writeShellScriptBin "attach-yubikey" (builtins.readFile "${scripts}/attach-yubikey.sh"))
      (pkgs.writeShellScriptBin "detach-yubikey" (builtins.readFile "${scripts}/detach-yubikey.sh"))
    ];
  };
}
