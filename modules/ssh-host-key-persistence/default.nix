# Persist the SSH host ed25519 key — and the sops-nix age identity derived from
# it — at /persist/ssh/ssh_host_ed25519_key, so both survive a container
# destroy/recreate that would otherwise wipe /etc/ssh and generate a fresh key
# (staling the committed .sops.yaml recipient).
#
# How it works:
#   - services.openssh.hostKeys is pinned to a single ed25519 key at the
#     persisted path. The default NixOS list also generates an rsa key; it is
#     dropped here — clients connect with ed25519, and only one key needs
#     persisting onto the dataset.
#   - sops.age.sshKeyPaths is set explicitly to the same path rather than left
#     at the sops-nix default that mirrors openssh.hostKeys, so the contract is
#     unambiguous and survives any future change to that default.
#
# The module only consumes /persist; it does not create or mount it. /persist is
# a bind mount the container's OpenTofu resource attaches to a per-host
# subdirectory of an encrypted ZFS dataset on the Proxmox host.
{
  config,
  lib,
  ...
}: let
  cfg = config.services.sshHostKeyPersistence;
  keyPath = "/persist/ssh/ssh_host_ed25519_key";
in {
  options.services.sshHostKeyPersistence = {
    enable = lib.mkEnableOption "persistence of the SSH host ed25519 key (and the sops-nix age identity derived from it) on /persist, so both survive LXC destroy/recreate";
  };

  config = lib.mkIf cfg.enable {
    services.openssh.hostKeys = [
      {
        type = "ed25519";
        path = keyPath;
      }
    ];

    sops.age.sshKeyPaths = [keyPath];
  };
}
