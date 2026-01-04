{
  config,
  lib,
  pkgs,
  username,
  ...
}: {
  virtualisation.docker = {
    enable = true;
    storageDriver = "btrfs";
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

  # Prevent Docker from starting in GDM session
  # Only allow it in the actual user session
  systemd.user.services.docker = {
    unitConfig = {
      ConditionUser = lib.mkForce username;
    };
  };
}
