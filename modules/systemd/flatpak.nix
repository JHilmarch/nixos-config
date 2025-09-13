{
  config,
  lib,
  pkgs,
  ...
}: {
  options = {
    services.systemdFlatpak = {
      enable = lib.mkEnableOption "Enable Flatpak systemd service";
    };
  };

  config = lib.mkIf config.services.systemdFlatpak.enable {
    services.flatpak = {
      enable = true;
    };

    systemd.services.systemdFlatpak = {
      description = "Configuring Flatpak";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
      };
      script = ''
        ${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        ${pkgs.flatpak}/bin/flatpak update --system --appstream -y || true
      '';
    };
  };
}
