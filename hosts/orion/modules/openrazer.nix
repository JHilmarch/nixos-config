{
  config,
  lib,
  pkgs,
  username,
  ...
}: {
  # Prevent OpenRazer from starting in GDM session
  # Only allow it in the actual user session
  systemd.user.services.openrazer-daemon = {
    unitConfig = {
      ConditionUser = lib.mkForce username;
    };
  };
}
