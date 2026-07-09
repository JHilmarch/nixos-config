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

1. **Cloudflare DNS** — an A record pointing `<svc>.fileshare.se` → `192.168.2.107` (edge's LAN IP).
1. **Edge nginx** — a `virtualHosts` entry (see [Adding a backend vhost](#adding-a-backend-vhost)) proxying to the
   backend's LAN address.

`cache.fileshare.se` is wired: edge terminates its TLS and reverse-proxies to the cache host's `nix-serve` at
`http://192.168.2.108:5000` (the cache host no longer runs its own nginx/ACME). Its A record must point at edge
(`192.168.2.107`), not the cache host.

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

On a fresh switch nginx starts with a self-signed fallback cert; ACME takes ~90 s to issue the real wildcard cert, after
which nginx must be reloaded:

```fish
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@192.168.2.107 \
  'systemctl start acme-order-renew-fileshare.se.service && systemctl reload nginx'
```

Start the **order** unit (`acme-order-renew-fileshare.se.service`), not `acme-fileshare.se.service`: the order unit is
the oneshot that runs `lego` and exits when the cert is issued.

## Files

| File                | Purpose                                                                                                    |
| ------------------- | ---------------------------------------------------------------------------------------------------------- |
| `configuration.nix` | Host config: networking, static IP, SSH, resolved, privileged override, nginx ingress + ACME cert enables. |
| `home.nix`          | Minimal Home Manager config.                                                                               |
