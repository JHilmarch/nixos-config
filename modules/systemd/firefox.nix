{
  config,
  lib,
  pkgs,
  ...
}: {
  options = {
    services.systemdFirefox = {
      enable = lib.mkEnableOption "Enable install/update Mozilla Firefox systemd service";
    };
  };

  config = lib.mkIf config.services.systemdFirefox.enable {
    systemd.services.systemdFirefox = {
      description = "Install/Update Mozilla Firefox as Flatpak";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target" "systemdFlatpak.service"];
      after = ["network-online.target" "systemdFlatpak.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
      };
      script = ''
        ${pkgs.flatpak}/bin/flatpak install --system -y --noninteractive flathub org.mozilla.firefox || true
        ${pkgs.flatpak}/bin/flatpak update --system -y --noninteractive org.mozilla.firefox || true
      '';
    };
  };
}
