# cache — LAN Nix binary cache

A Proxmox LXC that serves a Nix binary cache to the LAN, so hosts pull builds and dependencies from the local network
instead of the public caches.

- **Host:** `nixos-cache` (flake attribute) / `cache` (hostname), static IP `192.168.2.108`.
- **URL:** `https://cache.fileshare.se`.

## How it works

`nix-serve-ng` serves the host's local `/nix/store` on `127.0.0.1:5000`. Nginx fronts it with TLS on
`192.168.2.108:443`, using an ACME Cloudflare DNS-01 wildcard certificate for `*.fileshare.se`. Because it proxies the
local store, the cache serves both self-built artifacts and any upstream path the host has fetched.

The name `cache.fileshare.se` resolves to the LAN IP `192.168.2.108` (there is no public port-forward), so LAN clients
reach the cache directly while still getting a publicly-trusted Let's Encrypt certificate.

The container is **unprivileged** with the `nesting` feature enabled (`tofu/cache.tf` +
`proxmoxLXC.privileged = false`). Modern systemd needs nesting inside an LXC or its credential/namespace setup fails and
the system never activates; the `nesting` feature can only be set via the OpenTofu API token on an unprivileged
container.

Clients (`modules/nix-cache-client.nix`, imported by every LAN host) list `https://cache.fileshare.se` as their first
substituter, with `cache.numtide.com` and the built-in `cache.nixos.org` as ordered fallbacks — a down cache never
blocks a rebuild. The cache host is excluded from its own substituter list. Clients trust the cache's signing key
`cache.nixos-homelab-1:Y9QcUiR8SVS6X5fToHddfIG0asjY6+4NXi1PeVx1XYU=` so they verify what they download.

## Trust

The signing keypair is dedicated to this cache. The private key lives in SOPS (`secrets/cache/secrets.yml`, key
`nix-cache-priv-key`) and is passed to `nix-serve` as its `secretKeyFile`. The public key is trusted on every host. The
`cloudflare-token` secret in the same file drives the ACME DNS-01 challenge.

The `nix-cache-priv-key` value must be the whole key `nix-store --generate-binary-cache-key` emits — a single line of
the form `<name>:<base64-secret>` (e.g. `cache.nixos-homelab-1:…`), with **no** trailing newline. Storing only the
secret half makes `nix store sign` fail with `key is corrupt`; the pre-warm validates this shape and aborts loudly if it
is wrong. The `<name>` must match the public key in `modules/nix-cache-client.nix`.

The `fileshare.se` zone uses a `_acme-challenge` CNAME, and Cloudflare's authoritative nameservers refuse lego's
propagation checks. `cache.nix` therefore passes `--dns.propagation-wait 90s` so lego waits a fixed interval and lets
Let's Encrypt validate the record itself, rather than polling.

## SSH host key persistence

`sops-nix` decrypts the cache's secrets with the container's SSH host ed25519 key, converted to an age key via
`ssh-to-age`. That age public key is a committed recipient of `secrets/cache/` in `.sops.yaml`. Because the LXC rootfs
is disposable, a naive setup would regenerate the host key on every destroy/recreate and stale the recipient — forcing a
manual `sops updatekeys` each rebuild.

To make the key (and the derived age identity) survive recreate, the cache host enables `services.sshHostKeyPersistence`
([`modules/ssh-host-key-persistence/`](../../modules/ssh-host-key-persistence/)), which redirects both
`services.openssh.hostKeys` and `sops.age.sshKeyPaths` to `/persist/ssh/ssh_host_ed25519_key`. `/persist` is a Proxmox
bind mount, declared in `tofu/cache.tf`, that maps the host path `/hdd-zfs/keys/cache` — a subdirectory of the encrypted
`hdd-zfs/keys` dataset provisioned in #166 — into the container at `/persist`. The dataset is unlocked at the
Proxmox-host level during `tofu apply`, so a container rebuild needs no password; each container mounts only its own
subdirectory, so future containers (forge/runners) cannot read the cache's key.

### First-ever bootstrap (once per host lifetime)

On the very first boot there is no key on the dataset yet. `sshHostKeyPersistence` points sshd at `/persist/ssh/`, so
sshd's key-generation activation step creates the ed25519 keypair there on first switch. Derive the age public key from
it and commit it as the `cache` recipient:

```fish
# After the first nixos-rebuild switch onto hosts/cache with the /persist mount live:
ssh root@192.168.2.108 ssh-keygen -y -f /persist/ssh/ssh_host_ed25519_key | ssh-to-age
# → age1…   (paste this as the cache recipient in .sops.yaml, then:)
sops updatekeys secrets/cache/secrets.yml
```

Every later `tofu destroy`/`apply` cycle skips this entirely — the persisted key is remounted and the committed
recipient stays valid.

### Migrating a live host

To adopt persistence on a cache host that already has a committed recipient, copy the existing host key onto the dataset
before the first rebuild onto the new config, so the committed recipient never goes stale:

```fish
ssh root@<proxmox-host> pct push <ct-id> /etc/ssh/ssh_host_ed25519_key /hdd-zfs/keys/cache/ssh/ssh_host_ed25519_key --perms 600
ssh root@<proxmox-host> pct push <ct-id> /etc/ssh/ssh_host_ed25519_key.pub /hdd-zfs/keys/cache/ssh/ssh_host_ed25519_key.pub --perms 644
```

(`/persist` is `/hdd-zfs/keys/cache` on the host; the `ssh/` subdirectory must exist first.) Then rebuild — no
re-keying, no `sops updatekeys`.

## Provisioning

The Tofu container resources ignore changes to `operating_system` and `initialization`: the NixOS config owns the OS and
hostname after first boot, and Proxmox rejects clearing a running container's hostname (HTTP 400). `edge` also ignores
`features` — feature flags on a privileged container can only be changed by `root@pam`, not the OpenTofu API token (HTTP
403), so they stay operator-managed.

## Pre-warm

A `systemd` timer (`cache-prewarm`) fires twice daily at 06:00 and 18:00 (`Persistent`, so a missed run catches up).
Each run realises the system closure of every host in the flake into the local store and signs it with the cache key, so
a host's build is available on the LAN before that host asks for it. The host list is derived from
`self.nixosConfigurations` (excluding `nixos-cache`, `iso`, and `wsl-cab`); a single host that fails to build or sign is
logged and skipped.

## Files

| File                | Purpose                                                                      |
| ------------------- | ---------------------------------------------------------------------------- |
| `configuration.nix` | Host config: networking, `nix-serve`, signing key, SSH host key persistence. |
| `cache.nix`         | Nginx TLS reverse proxy + ACME Cloudflare wildcard.                          |
| `prewarm.nix`       | Twice-daily pre-warm service and timer.                                      |
| `prewarm.sh`        | Pre-warm shell body (build + sign each host closure).                        |
| `home.nix`          | Minimal Home Manager config.                                                 |
