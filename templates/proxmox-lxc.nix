# Shared base for every homelab Proxmox LXC host (edge, cache, and future ones).
#
# Beyond the raw proxmox-lxc virtualisation module this layers on the config
# that every homelab container needs identically, so a new host only declares
# its own static IP, stateVersion, secrets, and workload:
#
#   - Garbage collection — monthly age-based sweep (nix.gc) plus a niced/idle
#     serviceConfig, so a disposable store never accumulates stale closures.
#   - DNS — services.resolved owns resolv.conf (useHostResolvConf = false),
#     because the OpenTofu-provisioned LXC is created ostype=unmanaged, so
#     Proxmox never populates /etc/resolv.conf and DNS would otherwise break.
#   - LAN defaults — nameservers + gateway point at the router (192.168.2.1) via
#     mkDefault, so a host that lives elsewhere can still override them.
#   - SSH — openFirewall plus ssh-host-key-persistence, so the container's host
#     key (and the sops-nix age identity derived from it) survives a
#     destroy/recreate via the /persist bind mount.
#   - Unprivileged by default — the OpenTofu API token can only set the nesting
#     feature modern systemd needs on an unprivileged container.
{
  modulesPath,
  config,
  lib,
  self,
  ...
}: {
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ./server.nix
    "${self}/modules/ssh-host-key-persistence/default.nix"
  ];

  nix.settings.sandbox = false;

  # Monthly age-based GC of the container store, via the built-in nix.gc module
  # (systemd nix-gc service + timer). --delete-older-than 30d (never bare -d)
  # keeps the last month of closures so a recent rollback still resolves. The
  # timer fires at 04:00 on the 1st of each month; the serviceConfig override
  # nices the run and puts it in the idle IO class so a large sweep never
  # starves the box (the built-in module only sets Type = "oneshot").
  nix.gc = {
    automatic = true;
    dates = "*-*-01 04:00:00";
    options = "--delete-older-than 30d";
    persistent = true;
  };

  systemd.services.nix-gc.serviceConfig = {
    Nice = 19;
    IOSchedulingClass = "idle";
  };

  proxmoxLXC = {
    manageNetwork = true;
    privileged = lib.mkDefault false;
  };

  networking = {
    nameservers = lib.mkDefault ["192.168.2.1"];
    defaultGateway = lib.mkDefault "192.168.2.1";
    # The OpenTofu LXC is created ostype=unmanaged, so Proxmox never writes
    # /etc/resolv.conf; resolved writes it from networking.nameservers instead.
    useHostResolvConf = false;
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINZm7VWZl2HKD6ZPZWawFIunNLo3M6oJZSqe5lTQj64X tofu-remote-exec@p51"
  ];

  services = {
    fstrim.enable = false;
    resolved.enable = true;
    openssh.openFirewall = true;
    sshHostKeyPersistence.enable = true;
  };

  documentation.man.enable = false;
}
