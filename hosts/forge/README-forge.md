# forge — homelab git forge

A Proxmox LXC that will host the homelab's self-hosted git forge (Forgejo + Postgres). **Bare base host today** — the
workload lands in T2.

- **Host:** `nixos-forge` (flake attribute) / `forge` (hostname), CT 109, static IP `192.168.2.109`.
- **Container:** unprivileged + `nesting=true` (see
  [tofu/README.md "Nesting requirement"](../../tofu/README.md#nesting-requirement-systemd-256)).

## Current state

The host imports [`templates/proxmox-lxc.nix`](../../templates/proxmox-lxc.nix) and declares only its unique delta:
hostname, static IP (`192.168.2.109/24`), and `stateVersion`. The template provides nix.gc, resolved/DNS, LAN
nameservers + gateway, openssh `openFirewall`, SSH host-key persistence, unprivileged + nesting, and SOPS wiring.

No Forgejo, Postgres, `/persist` mount, or secrets are configured yet — those arrive in T2/T4.

## Edge ingress

Edge terminates TLS for `forge.fileshare.se` and reverse-proxies to `http://192.168.2.109:3000` (Forgejo's default HTTP
port) — LAN-only by default (RFC1918 allow-list). See [`hosts/edge/configuration.nix`](../edge/configuration.nix).

## Provisioning, bootstrap, and destroy/recreate

The generic LXC lifecycle (tofu apply, bootstrap onto flake config, destroy/recreate from code) is documented in
[`tofu/README.md`](../../tofu/README.md). The forge-specific values:

| What         | Value           |
| ------------ | --------------- |
| CT id        | 109             |
| Flake target | `.#nixos-forge` |
| Static IP    | `192.168.2.109` |
| Gateway      | `192.168.2.1`   |

## Files

| File                | Purpose                                                              |
| ------------------- | -------------------------------------------------------------------- |
| `configuration.nix` | Host config: networking, static IP. Bare base host (workload in T2). |
| `home.nix`          | Minimal Home Manager config (matches cache).                         |
