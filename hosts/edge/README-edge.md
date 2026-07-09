# edge — homelab ingress reverse-proxy

A Proxmox LXC that routes `<svc>.fileshare.se` subdomains to LAN backends via nginx, terminated with a `*.fileshare.se`
wildcard TLS certificate (Let's Encrypt, Cloudflare DNS-01).

- **Host:** `nixos-edge` (flake attribute) / `edge` (hostname), CT 107, static IP `192.168.2.107`.
- **Container:** unprivileged + `nesting=true` (see
  [tofu/README.md "Nesting requirement"](../../tofu/README.md#nesting-requirement-systemd-256)).

## How it works

Nginx terminates TLS for `*.fileshare.se` using an ACME Cloudflare DNS-01 wildcard certificate (`services.acmeWildcard`)
and proxies each subdomain to its LAN backend. The wildcard covers all current and future service subdomains without
per-service cert issuance.

Two things must be in place for a subdomain to work:

1. **LAN DNS** — `<svc>.fileshare.se` must resolve to `192.168.2.107` (edge's LAN IP) **for LAN clients**. Because this
   is a private address, the public Cloudflare record cannot serve it; set a local DNS rule on the router (which the
   hosts already use as nameserver `192.168.2.1`) — a single wildcard `*.fileshare.se → 192.168.2.107` covers every
   current and future subdomain, so adding a service needs no new DNS entry. The public Cloudflare `*.fileshare.se`
   record is only used by the ACME DNS-01 challenge, not for routing.
1. **Edge nginx** — a `virtualHosts` entry (see [Adding a backend vhost](#adding-a-backend-vhost)) proxying to the
   backend's LAN address. Edge routes by `server_name` (Host header), so DNS just has to get the client to edge.

`cache.fileshare.se` is wired: edge terminates its TLS and reverse-proxies to the cache host's `nix-serve` at
`http://192.168.2.108:5000` (the cache host no longer runs its own nginx/ACME). Its name must resolve to edge
(`192.168.2.107`) on the LAN, not the cache host.

**v1 is LAN-only.** No public port-forward exists, so only LAN clients reach edge — while still getting a
publicly-trusted Let's Encrypt certificate. Each vhost is also LAN-only *at the nginx layer*: `external = false` (the
default) restricts the `/` location to RFC1918 source ranges (`allow 10/8, 172.16/12, 192.168/16; deny all;`), so even
if the firewall or a port-forward exposed 443, an internal vhost stays private. The external subdomain tier is codified
but dormant: activating a vhost requires setting `external = true` **and** a single WAN → `192.168.2.107` port-forward
on the home router (ports 80/443).

## Adding a backend vhost

Add one `services.nginxIngress.virtualHosts` entry per backend service in [`configuration.nix`](./configuration.nix).
The [`nginx-ingress`](../../modules/nginx-ingress/default.nix) module applies `forceSSL`, `useACMEHost = "fileshare.se"`
(the wildcard cert), and the `locations."/".proxyPass` wrapper automatically, so each backend is just its upstream:

```nix
services.nginxIngress.virtualHosts."myapp.fileshare.se" = {
  proxyPass = "http://192.168.2.<backend>:<port>";
  # external = true;  # opt into the WAN tier (drops the RFC1918 allow-list)
};
```

`recommendedProxySettings` (enabled by the module) supplies the standard proxy headers. Each vhost is **LAN-only by
default** (`external = false`): the module injects an RFC1918 `allow … deny all;` into the `/` location, so only
private-range clients reach the backend. Set `external = true` to drop the allow-list and expose the vhost publicly —
that single flag (plus a router port-forward) is the whole opt-in to the external tier.

## SSH host key persistence

Edge bind-mounts its own subdirectory of the encrypted `hdd-zfs/keys` dataset at `/persist` and enables
[`services.sshHostKeyPersistence`](../../modules/ssh-host-key-persistence/default.nix), so its SSH host key — and the
sops-nix age identity derived from it — survives a destroy/recreate. That means a recreated edge keeps decrypting
`secrets/edge/secrets.yml` (the `cloudflare-token`) with no manual `sops updatekeys`.

The mount's key material is chowned to the container-root uid (`100000:100000`) automatically by the tofu bind-mount
provisioner ([`tofu/modules/lxc/main.tf`](../../tofu/modules/lxc/main.tf)) — a host-root/`nobody`-owned key is
unreadable by the in-container sshd and sops-nix and crash-loops sshd, so no manual `chown` step is needed.

### First-ever bootstrap (once per host lifetime)

On the very first boot there is no key on the dataset yet. `sshHostKeyPersistence` points sshd at `/persist/ssh/`, so
sshd's key-generation step creates the ed25519 keypair there on first switch. Derive the age public key from it and
commit it as the `edge` recipient in `.sops.yaml`, then re-encrypt:

```fish
# After the first switch onto hosts/edge with the /persist mount live.
# Pipe ssh-to-age locally — it is not installed on edge:
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@192.168.2.107 \
  'ssh-keygen -y -f /persist/ssh/ssh_host_ed25519_key' | ssh-to-age
# → age1…   (set this as the &edge recipient in .sops.yaml, then:)
sops updatekeys secrets/edge/secrets.yml
```

If the committed `&edge` recipient does not match the persisted key, sops-nix fails at activation with
`Error getting data key: 0 successful groups required, got 0`, `cloudflare.env` never renders, and the ACME order unit
fails to load its `EnvironmentFile`. Re-key per the block above to fix it. Commit both `.sops.yaml` and the re-encrypted
`secrets/edge/secrets.yml` so the flake source (which sops reads from the store) carries the correct recipient before
the next switch.

Every later `tofu destroy`/`apply` cycle skips this — the persisted key is remounted (and chowned automatically) and the
committed recipient stays valid.

## Provisioning, bootstrap, and destroy/recreate

The generic LXC lifecycle (tofu apply, bootstrap onto flake config, destroy/recreate from code) is documented in
[`tofu/README.md`](../../tofu/README.md). The edge-specific values:

| What         | Value                             |
| ------------ | --------------------------------- |
| CT id        | 107                               |
| Flake target | `.#nixos-edge`                    |
| Static IP    | `192.168.2.107`                   |
| Gateway      | `192.168.2.1`                     |
| Bind mount   | `/hdd-zfs/keys/edge` → `/persist` |

## ACME cert after first switch

Steady-state, ACME renewal reloads nginx automatically (`security.acme` sets `reloadServices = ["nginx.service"]`). The
manual step below is only for the **first** switch: nginx starts with a self-signed fallback cert because no real cert
exists yet, and the initial order runs asynchronously, so on a fresh converge you trigger the order once and reload:

```fish
# Non-blocking + watch — the order waits ~90 s for DNS propagation. Do NOT Ctrl-C
# before it finishes ("Server responded with a certificate"), or lego is killed
# mid-issuance and nginx keeps the fallback.
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@192.168.2.107 \
  'systemctl start --no-block acme-order-renew-fileshare.se.service; \
   journalctl -u acme-order-renew-fileshare.se.service -f'
# Once issued, reload nginx:
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@192.168.2.107 'systemctl reload nginx'
```

Start the **order** unit (`acme-order-renew-fileshare.se.service`), not `acme-fileshare.se.service`: the order unit is
the oneshot that runs `lego` and exits when the cert is issued, so `systemctl start` blocks until it finishes;
`acme-fileshare.se.service` stays `active` and polling it hangs forever.

`/var/lib/acme` is **not** persisted across destroy/recreate, so a recreated edge re-issues the wildcard cert (~90 s,
well within Let's Encrypt rate limits). Persisting it onto `/persist` would avoid the re-issue but reintroduces a second
uid-mapped bind mount fighting systemd's `StateDirectory`; the re-issue is cheap enough that it is left as a future
improvement.

## Files

| File                | Purpose                                                                                                    |
| ------------------- | ---------------------------------------------------------------------------------------------------------- |
| `configuration.nix` | Host config: networking, static IP, SSH, resolved, privileged override, nginx ingress + ACME cert enables. |
| `home.nix`          | Minimal Home Manager config.                                                                               |
