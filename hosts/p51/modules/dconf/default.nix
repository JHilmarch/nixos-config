{
  pkgs,
  lib,
  username,
  ...
}: let
  baseLine = import ./base-line.nix {inherit lib username;};
  inputSources = import ./input-sources.nix {inherit lib;};
  nightLight = import ./night-light.nix;
  powerLock = import ./power-lock.nix {inherit lib;};
  workspaceSettings = import ./workspace-settings.nix;
  mediaKeys = import ./media-keys.nix;
  customKeybindings = import ./custom-keybindings.nix;
  workspaceShortcuts = import ./workspace-shortcuts.nix {inherit pkgs;};
  spotifyShortcuts = import ./spotify-shortcuts.nix;
  tilingShellSettings = import ./tiling-shell.nix;
in {
  dconf.settings = lib.foldl lib.recursiveUpdate baseLine [
    inputSources
    nightLight
    powerLock
    workspaceSettings
    mediaKeys
    customKeybindings
    workspaceShortcuts
    spotifyShortcuts
    tilingShellSettings
  ];
}
