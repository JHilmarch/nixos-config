# forge — homelab git forge

A Proxmox LXC that will host the homelab's self-hosted git forge (Forgejo + Postgres). **Bare base host today** — the
workload lands in T2.

- **Host:** `nixos-forge` (flake attribute) / `forge` (hostname), CT 109, static IP `192.168.2.109`.
- **Container:** unprivileged + `nesting=true` (see
  [tofu/README.md "Nesting requirement"](../../tofu/README.md#nesting-requirement-systemd-256)).

## Current state

The host imports [`templates/proxmox-lxc.nix`](../../templates/proxmox-lxc.nix) and declares only its unique delta:
hostname, static IP (`192.168.2.109/24`), `stateVersion`, SSH host-key persistence, and its SOPS secret entries. The
template provides nix.gc, resolved/DNS, LAN nameservers + gateway, openssh `openFirewall`, unprivileged + nesting, and
SOPS wiring.

No Forgejo or Postgres workload is configured yet — that arrives in T2.

## Secrets and key persistence

`services.sshHostKeyPersistence.enable` redirects the SSH host key (and the sops-nix age identity derived from it) to
the `/persist` bind mount, so the committed `.sops.yaml` recipient survives a container destroy/recreate with no
`sops updatekeys`. `/persist` is `tofu/forge.tf`'s `mount_points` entry mapping `/hdd-zfs/keys/forge` — the per-host
subdirectory of the encrypted ZFS dataset — into the container. See
[`README-cache.md` "SSH host key persistence"](../cache/README-cache.md#ssh-host-key-persistence) for the shared
mechanism and the first-ever-bootstrap flow that derives the age recipient.

The `sops.secrets` entries (`forgejo-secret-key`, `forgejo-internal-token`, `forgejo-db-password`,
`restic-forge-password`) expose the decrypted paths consumed by the Forgejo service and the restic backup. Their owner
and group are left at the default until the Forgejo service (and its user) exist; the workload attaches ownership when
it wires the secrets. The encrypted `secrets/forge/secrets.yml` and the `&forge` recipient in `.sops.yaml` are the
operator's YubiKey-gated bootstrap step.

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

| File                | Purpose                                                                            |
| ------------------- | ---------------------------------------------------------------------------------- |
| `configuration.nix` | Host config: networking, static IP, SSH host-key persistence, SOPS secret entries. |
| `home.nix`          | Minimal Home Manager config (matches cache).                                       |
