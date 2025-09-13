{
  config,
  lib,
  pkgs,
  ...
}: {
  options = {
    services.systemdMullvadBrowser = {
      enable = lib.mkEnableOption "Enable install/update Mullvad Browser systemd service";
    };
  };

  config = lib.mkIf config.services.systemdMullvadBrowser.enable {
    systemd.services.systemdMullvadBrowser = {
      description = "Install/Update Mullvad Browser as Flatpak";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target" "systemdFlatpak.service"];
      after = ["network-online.target" "systemdFlatpak.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
      };
      script = ''
        ${pkgs.flatpak}/bin/flatpak install --system -y --noninteractive flathub net.mullvad.MullvadBrowser || true
        ${pkgs.flatpak}/bin/flatpak update --system -y --noninteractive net.mullvad.MullvadBrowser || true
      '';
    };
  };
}
