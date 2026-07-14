# runners — self-hosted CI runner host

A Proxmox LXC that will host the homelab's self-hosted CI runners, executing workflows for repositories on the
[`forge` host](../forge/README-forge.md).

- **Host:** `nixos-runners` (flake attribute) / `runners` (hostname), static IP `192.168.2.110`.

## How it works

The host imports [`templates/proxmox-lxc.nix`](../../templates/proxmox-lxc.nix), which provides the shared LXC base:
garbage collection, DNS via `systemd-resolved`, LAN nameserver/gateway defaults, SSH with an open firewall port, and
unprivileged+nesting container defaults. The host config declares only its delta: the hostname, the static IP
`192.168.2.110`, a capped Nix build environment, and SSH host key persistence.

`services.sshHostKeyPersistence` ([`modules/ssh-host-key-persistence/`](../../modules/ssh-host-key-persistence/)) is
enabled so the SSH host ed25519 key — and the age identity sops-nix derives from it — survives container
destroy/recreate via the `/persist` bind mount ([`../../tofu/runners.tf`](../../tofu/runners.tf)).

### Build environment

`nix.settings` caps the build environment so a heavy build cannot starve the fleet: `max-jobs = 6` bounds parallel
derivations to the container's core cap, `cores = 0` lets each build use all available cores, and `trusted-users`
includes `root` so `nixos-rebuild`'s build user accepts signed paths from the LAN cache non-interactively. The LAN cache
substituter (`https://cache.fileshare.se`) and its public key come from
[`../../modules/nix-cache-client.nix`](../../modules/nix-cache-client.nix) via the template — the host does not
redeclare them.

### Provisioning

The container (CT `110`) is created and sized by OpenTofu in [`../../tofu/runners.tf`](../../tofu/runners.tf): 6 cores,
12 GB memory, 4 GB swap, NVMe `local-lvm` rootfs, and a single `/persist` bind mount for the SSH host key. See
[`../../tofu/README.md`](../../tofu/README.md) for the full provisioning, bootstrap, and reboot-relock flow.

## Bootstrap

`tofu apply -target module.runners` creates the container **running** on DHCP from the base template. Converge it onto
this flake host config once, over `--target-host` (no push needed), then reboot onto the static IP. Run from the repo
root on p51:

```fish
# 1. Find the DHCP lease the template booted with.
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@<proxmox-host> \
  'pct exec 110 -- /run/current-system/sw/bin/ip -4 -br addr show eth0'

# 2. Build + push the closure + activate (SSH drops mid-activation — expected, not a hang).
set lease <dhcp-addr-from-step-1>
sudo env NIX_SSHOPTS="-i /home/<user>/.ssh/id_ed25519_tofu -o IdentitiesOnly=yes" \
  nixos-rebuild switch --flake .#nixos-runners --target-host root@$lease

# 3. Reboot to settle onto the static IP 192.168.2.110.
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@<proxmox-host> 'pct reboot 110'
```

Point `NIX_SSHOPTS` at the **absolute** key path — `sudo` runs as root, so a `~` there resolves to `/root`, not your
home. Later rebuilds target the static IP `192.168.2.110` directly and do not drop (networking no longer flips).

Verify:

```fish
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@192.168.2.110 'hostname'                          # → runners
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@<proxmox-host> 'pct config 110 | grep -E "cores|memory|swap"'  # cores=6 memory=12288 swap=4096
```

## Files

| File                | Purpose                                                                  |
| ------------------- | ------------------------------------------------------------------------ |
| `configuration.nix` | Host config: networking, capped Nix build env, SSH host key persistence. |
| `home.nix`          | Minimal Home Manager config (fish, lsd, fzf, zoxide, broot, starship).   |
