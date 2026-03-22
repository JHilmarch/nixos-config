{
  lib,
  pkgs,
  ...
}: {
  imports = builtins.attrValues (import ../users/default.nix) ++ [./common.nix];

  users.defaultUserShell = lib.mkOverride 1499 pkgs.fish;

  security.polkit.enable = true;

  environment.shells = with pkgs; [fish bash];
}
