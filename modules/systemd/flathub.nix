{ config, pkgs, ... }:
{
  services.flatpak = {
    enable = true;
  };

  systemd.services.configure-flathub = {
    description = "Configure Flathub repository";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
    };
    script = ''
      ${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    '';
  };
}
