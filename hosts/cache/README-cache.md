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

The container rootfs — and therefore its `/nix/store` — lives on the bulk **`hdd-zfs`** ZFS mirror pool, not the Proxmox
host's NVMe `local-lvm` pool. The store wants capacity (it pre-warms every host's full closure plus upstream artifacts),
not latency, and the cache does no latency-sensitive work. `tofu/cache.tf` overrides the shared module's
`container_datastore` to `var.hdd_zfs_storage_id` for the cache instance only; the root disk is sized at 512 GB
(thin-provisioned on ZFS, so only what is written is consumed). See
[`tofu/README.md` "Cache rootfs on the HDD pool"](../../tofu/README.md#cache-rootfs-on-the-hdd-pool) for the datastore
mechanism and the operator step to move an existing container's rootfs.

The container is **unprivileged** with the `nesting` feature enabled (`tofu/cache.tf` +
`proxmoxLXC.privileged = false`). Modern systemd needs nesting inside an LXC or its credential/namespace setup fails and
the system never activates; the `nesting` feature can only be set via the OpenTofu API token on an unprivileged
container.

DNS is owned by `systemd-resolved` (`services.resolved.enable` + `networking.useHostResolvConf = false`). The
container-config default `useHostResolvConf = true` expects Proxmox to populate `/etc/resolv.conf`, but the
OpenTofu-provisioned LXC is created `ostype=unmanaged`, so Proxmox never writes it — leaving `resolv.conf` without a
nameserver, which breaks DNS resolution and thus ACME. `resolved` instead writes `resolv.conf` from
`networking.nameservers` on every activation, surviving destroy/recreate.

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
propagation checks. The shared [`acme-wildcard`](../../modules/acme-wildcard/default.nix) module therefore passes
`--dns.propagation-wait 90s` so lego waits a fixed interval and lets Let's Encrypt validate the record itself, rather
than polling.

## SSH host key persistence

`sops-nix` decrypts the cache's secrets with the container's SSH host ed25519 key, converted to an age key via
`ssh-to-age`. That age public key is a committed recipient of `secrets/cache/` in `.sops.yaml`. Because the LXC rootfs
is disposable, a naive setup would regenerate the host key on every destroy/recreate and stale the recipient — forcing a
manual `sops updatekeys` each rebuild.

To make the key (and the derived age identity) survive recreate, the cache host enables `services.sshHostKeyPersistence`
([`modules/ssh-host-key-persistence/`](../../modules/ssh-host-key-persistence/)), which redirects both
`services.openssh.hostKeys` and `sops.age.sshKeyPaths` to `/persist/ssh/ssh_host_ed25519_key`. `/persist` is a Proxmox
**bind mount** of the host path `/hdd-zfs/keys/cache` — a subdirectory of the encrypted `hdd-zfs/keys` dataset
provisioned in #166. The dataset is unlocked at the Proxmox-host level during `tofu apply`, so a container rebuild needs
no password; each container mounts only its own subdirectory, so future containers (forge/runners) cannot read the
cache's key.

Proxmox restricts bind mounts to the `root@pam` user, so the API token Tofu authenticates as cannot declare the mount as
a native `mount_point` block. The LXC module applies it instead via a `null_resource` that runs `pct set -mpN` over root
SSH (the `id_ed25519_tofu` key from #166) right after the container is created — see `tofu/modules/lxc/main.tf`.
`replace_triggered_by` re-runs it on every (re)create, so the mount is re-attached automatically on each rebuild.

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
ssh root@<proxmox-host> 'mkdir -p /hdd-zfs/keys/cache/ssh'
ssh root@<proxmox-host> pct pull <ct-id> /etc/ssh/ssh_host_ed25519_key     /hdd-zfs/keys/cache/ssh/ssh_host_ed25519_key
ssh root@<proxmox-host> pct pull <ct-id> /etc/ssh/ssh_host_ed25519_key.pub /hdd-zfs/keys/cache/ssh/ssh_host_ed25519_key.pub
```

**Then chown to the container-root mapping.** `pct pull` writes as host-root (uid 0), which maps to `nobody` (65534)
inside the **unprivileged** container — sshd and sops run as container-root (host uid 100000 by Proxmox's default
subuid) and cannot read a `nobody`-owned 600 file. Chown to `100000:100000` on the host so the files appear as
`root:root` in-container:

```fish
ssh root@<proxmox-host> chown -R 100000:100000 /hdd-zfs/keys/cache/ssh
```

(The first-ever bootstrap path — letting sshd generate the key into `/persist/ssh/` — does not hit this: sshd writes as
container-root, the correct mapped uid already.) Then rebuild per
[Rebuilding the cache host](#rebuilding-the-cache-host) — no re-keying, no `sops updatekeys`.

## Rebuilding the cache host

After any `tofu destroy`/`apply` of the cache container (or a fresh provision), converge it back onto its flake host
config. Tofu creates the container **on its static IP `192.168.2.108`** (`ipv4_address` in `tofu/cache.tf`), so there is
no DHCP-lease hunt — the container is reachable immediately after `apply`. The operator (tofu) SSH key is declared in
two places so root SSH works across the whole lifecycle: baked into the LXC template
([`templates/lxc-base.nix`](../../templates/lxc-base.nix)) for first boot, and re-declared in the running config
([`templates/proxmox-lxc.nix`](../../templates/proxmox-lxc.nix)) so the `nixos-rebuild` switch doesn't remove it as an
obsolete file — no manual key injection at any step.

> **A destroy/recreate wipes `/nix/store`.** The store lives on the container rootfs (on the `hdd-zfs` pool), which is
> deleted with the container, so the store re-warms on the next [pre-warm](#pre-warm) run — the first pull comes from
> the public caches and is slow. The SSH host key survives via the [`/persist` mount](#ssh-host-key-persistence), so no
> `sops updatekeys` is needed. See
> [`tofu/README.md` "Cache rootfs on the HDD pool"](../../tofu/README.md#cache-rootfs-on-the-hdd-pool).

1. **Apply** — creates CT 108 on the static IP and the `null_resource` attaches the `/persist` bind mount over root SSH:

   ```fish
   fish scripts/tofu-sops.fish apply
   ```

1. **Clear the stale host key.** The recreated container boots the template sshd (host key at `/etc/ssh`), which differs
   from the persisted key that takes over after the switch — so `known_hosts` still holds the old key and refuses the
   connection. Remove it:

   ```fish
   ssh-keygen -R 192.168.2.108
   ```

1. **Rebuild** from a host with the flake checked out (e.g. p51). The LAN cache is the container being rebuilt, so it is
   down — override the substituters to skip it and pull straight from the public caches.
   `StrictHostKeyChecking=accept-new` auto-accepts the template's new host key without prompting:

   ```fish
   NIX_SSHOPTS="-o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu -o StrictHostKeyChecking=accept-new" \
     nixos-rebuild switch --flake .#nixos-cache --target-host root@192.168.2.108 \
     --option substituters "https://cache.numtide.com https://cache.nixos.org"
   ```

   The switch moves sshd onto the persisted key, so the host key **changes again** at this point. Clear it once more
   before the next SSH:

   ```fish
   ssh-keygen -R 192.168.2.108
   ```

1. **Reload nginx after ACME finishes.** On a fresh switch nginx starts immediately and serves a generated self-signed
   fallback cert; ACME takes ~90 s (`--dns.propagation-wait`) to issue the real one, after which nginx must be reloaded
   to pick it up. **Wait for ACME first** — reload too early and nginx keeps the fallback:

   ```fish
   # Block on the LE order unit (finishes in ~90 s), then reload nginx.
   ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu -o StrictHostKeyChecking=accept-new root@192.168.2.108 \
     'systemctl start acme-order-renew-fileshare.se.service && systemctl reload nginx'
   ```

   Start the **order** unit (`acme-order-renew-fileshare.se.service`), not `acme-fileshare.se.service`: the order unit
   is the oneshot that runs `lego` and exits when the cert is issued, so `systemctl start` blocks until it finishes.
   `acme-fileshare.se.service` stays `active` and never reaches an `inactive` state, so polling it hangs forever. (If
   you skip the wait, just re-run `systemctl reload nginx` after ~90 s.) The cert itself survives container
   destroy/recreate only if `/var/lib/acme` is persisted — currently it is not, so ACME re-issues on every recreate;
   persisting it is a future improvement.

   > **nix-serve sets `HOME=/var/empty`** (\[`hosts/cache/configuration.nix`\]) because it runs under `DynamicUser`,
   > whose allocated UID has no passwd entry — without an explicit `HOME`, the nix library's home lookup ABRTs
   > (`cannot determine user's home directory`) on start. With `HOME` set, the switch starts it clean (no reboot
   > needed).

1. **Verify** end-to-end over TLS:

   ```fish
   curl -fsS https://cache.fileshare.se/nix-cache-info
   # → StoreDir: /nix/store
   #   WantMassQuery: 1
   #   Priority: 30
   ```

No `sops updatekeys` at any step — the persisted SSH host key keeps the committed `.sops.yaml` recipient valid across
destroy/recreate. Commit the refreshed tofu state after the apply:

```fish
git add tofu/terraform.tfstate.enc
```

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

To trigger a run manually (e.g. right after a destroy/recreate, when the store is empty), start it without blocking —
`systemctl start` otherwise waits for the whole (long) oneshot to finish — and tail the log:

```fish
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@192.168.2.108 \
  'systemctl start --no-block cache-prewarm; journalctl -u cache-prewarm -f'
```

The first run after a recreate pulls every closure from the public caches (the LAN cache *is* the empty container being
populated), so it is slow; later timer runs are incremental. Ctrl-C the `journalctl -f` once it's progressing — the
service keeps running in the background.

## Files

| File                | Purpose                                                                                                         |
| ------------------- | --------------------------------------------------------------------------------------------------------------- |
| `configuration.nix` | Host config: networking, `nix-serve`, signing key, SSH host key persistence, nginx ingress + ACME cert enables. |
| `prewarm.nix`       | Twice-daily pre-warm service and timer.                                                                         |
| `prewarm.sh`        | Pre-warm shell body (build + sign each host closure).                                                           |
| `home.nix`          | Minimal Home Manager config.                                                                                    |
