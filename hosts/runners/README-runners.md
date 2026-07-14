# runners — self-hosted CI runner host

A Proxmox LXC that will host the homelab's self-hosted CI runners, executing workflows for repositories on the
[`forge` host](../forge/README-forge.md).

- **Host:** `nixos-runners` (flake attribute) / `runners` (hostname), static IP `192.168.2.110`.

## How it works

The host imports [`templates/proxmox-lxc.nix`](../../templates/proxmox-lxc.nix), which provides the shared LXC base:
garbage collection, DNS via `systemd-resolved`, LAN nameserver/gateway defaults, SSH with an open firewall port, and
unprivileged+nesting container defaults. The host config declares only its delta: the hostname, the static IP
`192.168.2.110`, and SSH host key persistence.

`services.sshHostKeyPersistence` ([`modules/ssh-host-key-persistence/`](../../modules/ssh-host-key-persistence/)) is
enabled so the SSH host ed25519 key — and the age identity sops-nix derives from it — survives container
destroy/recreate once the `/persist` bind mount and SOPS secrets are wired in follow-up work.

The CI runner workload (Forgejo Actions runner), container resource caps, Tofu provisioning, and runner registration
secrets are added in follow-up work. Right now the host is a bare LXC base config.

## Files

| File                | Purpose                                                                |
| ------------------- | ---------------------------------------------------------------------- |
| `configuration.nix` | Host config: networking on `192.168.2.110`, SSH host key persistence.  |
| `home.nix`          | Minimal Home Manager config (fish, lsd, fzf, zoxide, broot, starship). |
