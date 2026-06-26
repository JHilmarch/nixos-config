{username, ...}: {
  # SSH from orion to the P51. The P51 has a dynamic IP, so target its local
  # DNS name (nixos-p51.lan, resolved by the router) instead of an address.
  # IdentityFile is inherited from the "*" block in home-modules/ssh/default.nix
  # (the real YubiKey resident keys); IdentitiesOnly restricts ssh to those so
  # it doesn't offer every key in the 1Password agent.
  programs.ssh.settings.p51 = {
    HostName = "nixos-p51.lan";
    User = "${username}";
    IdentitiesOnly = true;
    ForwardAgent = false;
  };
}
