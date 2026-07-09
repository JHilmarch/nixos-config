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

Neither `edge.fileshare.se` nor `cache.fileshare.se` has a vhost configured yet — add them when the backends are ready.

**v1 is LAN-only.** No public port-forward exists, so only LAN clients reach edge — while still getting a
publicly-trusted Let's Encrypt certificate. The external subdomain tier is codified but dormant: activating it later
requires a single WAN → `192.168.2.107` port-forward on the home router (ports 80/443).

## Adding a backend vhost

Add one `virtualHosts` entry per backend service in [`nginx.nix`](./nginx.nix). Use `lanOnly` for LAN-only access or
`wanOpen` for WAN (requires the router port-forward):

```nix
services.nginx.virtualHosts."myapp.fileshare.se" = {
  forceSSL = true;
  useACMEHost = "fileshare.se";      # reuses the wildcard cert
  extraConfig = lanOnly;             # or wanOpen
  locations."/" = {
    proxyPass = "http://192.168.2.<backend>:<port>";
  };
};
```

`recommendedProxySettings` supplies the standard proxy headers, so entries stay small.

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

| File                | Purpose                                                                 |
| ------------------- | ----------------------------------------------------------------------- |
| `configuration.nix` | Host config: networking, static IP, SSH, resolved, privileged override. |
| `nginx.nix`         | Nginx TLS reverse proxy + ACME wildcard cert + firewall.                |
| `home.nix`          | Minimal Home Manager config.                                            |
