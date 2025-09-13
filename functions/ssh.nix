# from https://github.com/ankarhem/nix-config/blob/fde51be53d4def93322b7f8df639613b4aa490a4/helpers/ssh.nix
{pkgs}: {
  getGithubKeys = {
    username,
    sha256,
  }: let
    authorizedKeysFile = builtins.fetchurl {
      url = "https://github.com/${username}.keys";
      inherit sha256;
    };
    keys = pkgs.lib.splitString "\n" (builtins.readFile authorizedKeysFile);
  in
    builtins.filter (s: s != "") keys;
}
