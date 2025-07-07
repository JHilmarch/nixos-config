{ lib, ... }:
{
  imports = [ ./default.nix ];

  host = "fileshare.local";
  ip = "192.168.2.103";
  shares = [
    { path = "/mnt/FILESHARE_SHARE"; device = "/volume2/SHARE"; }
    { path = "/mnt/FILESHARE_JONATAN_ARKIV"; device = "/volume2/Jonatan arkiv"; }
  ];
  nfsShareOptions = [
    "nfsvers=4"
    "x-systemd.automount"
    "noauto"
  ];
}
