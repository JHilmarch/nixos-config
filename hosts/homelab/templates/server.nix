{ ... }: {
  imports = [
    ./base.nix
  ] ++ builtins.attrValues (import ../users/default.nix);

  # disable logging to disk for generic servers
  services.journald.extraConfig = ''
    Storage=volatile;
    RuntimeMaxUse=30M;
  '';
}
