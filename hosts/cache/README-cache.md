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

## SOPS host key

`sops-nix` decrypts the cache's secrets with the container's SSH host key (`/etc/ssh/ssh_host_ed25519_key`), converted
to an age key. That age public key is a recipient of `secrets/cache/` in `.sops.yaml`. Because the LXC rootfs is
disposable, destroying and recreating the container generates a new host key: regenerate it, add the new age key as the
`cache` recipient, and re-encrypt (`sops updatekeys secrets/cache/secrets.yml`) before the host can decrypt its secrets
again.

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

| File                | Purpose                                               |
| ------------------- | ----------------------------------------------------- |
| `configuration.nix` | Host config: networking, `nix-serve`, signing key.    |
| `cache.nix`         | Nginx TLS reverse proxy + ACME Cloudflare wildcard.   |
| `prewarm.nix`       | Twice-daily pre-warm service and timer.               |
| `prewarm.sh`        | Pre-warm shell body (build + sign each host closure). |
| `home.nix`          | Minimal Home Manager config.                          |
