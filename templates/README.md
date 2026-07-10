# Host base templates

Composable NixOS bases shared across hosts, plus the standalone LXC image the homelab boots from.

## Host bases (imported by `hosts/<name>/`)

The classic chain, pulled in via `imports = ["${self}/templates/<file>.nix"]`:

```
desktop.nix ─┐
             ├─ common.nix ─ modules/defaults.nix
server.nix ──┘
proxmox-lxc.nix ─ server.nix ─ common.nix ─ modules/defaults.nix
```

These depend on host machinery (`self`, `username`, `users/`, SOPS) and are only meant to be imported by a
`nixosConfiguration`, not built on their own.

### `proxmox-lxc.nix` — the shared homelab-container base

Every homelab Proxmox LXC host (`edge`, `cache`, and future ones) imports `proxmox-lxc.nix`. Beyond the raw
`proxmox-lxc` virtualisation module it layers on the config that every container needs **identically**, so a new host
only declares its own delta (static IP, `stateVersion`, workload, secrets):

| Concern                   | What the template sets                                                     |
| ------------------------- | -------------------------------------------------------------------------- |
| Garbage collection        | `nix.gc` monthly `--delete-older-than 30d`, niced + IO-idle serviceConfig  |
| DNS                       | `services.resolved.enable` + `networking.useHostResolvConf = false`        |
| LAN nameservers + gateway | `["192.168.2.1"]` / `"192.168.2.1"` via `mkDefault` (a host can override)  |
| SSH                       | `openssh.openFirewall` + `services.sshHostKeyPersistence.enable`           |
| Container                 | `proxmoxLXC.privileged = mkDefault false` (nesting is a tofu feature flag) |

The GC sweep is proactive and store-agnostic; a host under disk pressure (e.g. `cache`) layers its own reactive
`min-free`/`max-free` on top. To add a new LXC host, use the `scaffold-lxc-host` skill — it walks the full delta (host
dir, flake wiring, tofu resource, secrets, README).

## `lxc-base.nix` — the homelab LXC template image

`lxc-base.nix` is deliberately **standalone**: it does *not* import the host chain above, so it can be built from a
clean checkout and consumed by OpenTofu as a Proxmox CT template.

It is a minimal base that only needs to:

1. boot as an unprivileged Proxmox LXC with `nesting=true` (required for systemd 256+ — see
   [`tofu/README.md`](../tofu/README.md) "Nesting requirement"),
1. come up on the network (DHCP; the per-host flake config takes over static addressing),
1. accept key-based SSH (the `id_ed25519_tofu` key is baked into root's `authorized_keys`), and
1. carry `nix` + `git` + `iproute2` so `nixos-rebuild switch --flake .#<host>` can take over — after which this base is
   fully superseded by the real host config.

### Build

```fish
nix build .#lxc-template
ls -la result/          # proxmox-lxc root tarball
```

The output is a Proxmox-LXC-format root tarball, wired as the `lxc-template` flake package output in
[`../flake.nix`](../flake.nix).

### Register it on the Proxmox host as a CT template

The template is built on-demand by the operator and uploaded (not pulled from a public registry). The container resource
references it by a **fixed, stable name** so provisioning is reproducible:

| What                  | Value                                   |
| --------------------- | --------------------------------------- |
| Datastore             | `local`                                 |
| Template file name    | `nixos-homelab-lxc.tar.xz`              |
| Full volume id (Tofu) | `local:vztmpl/nixos-homelab-lxc.tar.xz` |

Upload the freshly built tarball under that fixed name:

```fish
# Build, then copy the tarball to the Proxmox template cache under the stable name.
nix build .#lxc-template

# The result is a store path; copy the tarball out under the fixed template name.
set tarball (find -L result -maxdepth 2 -name '*.tar.*' | head -n1)
scp -o IdentitiesOnly=yes $tarball root@<proxmox-host>:/var/lib/vz/template/cache/nixos-homelab-lxc.tar.xz
```

If your SSH agent offers several keys, Proxmox may reject the connection before the right key is tried;
`-o IdentitiesOnly=yes` forces SSH to use only the configured key.

Confirm Proxmox sees it:

```fish
ssh -o IdentitiesOnly=yes root@<proxmox-host> pveam list local
# → local:vztmpl/nixos-homelab-lxc.tar.xz
```

> Re-run this whenever the base image changes (e.g. a nixpkgs bump). Keep the file name stable so the container resource
> keeps resolving without a Tofu change; the tarball contents can change underneath the name freely.

### How Tofu references it

A container resource consumes the template via its fixed volume id:

```hcl
resource "proxmox_virtual_environment_container" "edge" {
  # ...
  operating_system {
    template_file_id = "local:vztmpl/nixos-homelab-lxc.tar.xz"
    type             = "nixos"
  }
}
```

### systemd v260 `/run` workaround (nixpkgs#529888)

systemd v260 (nixpkgs 26.05) mounts a fresh tmpfs over `/run` when it starts as PID 1, shadowing `/run/current-system`
and `/run/booted-system` that stage-2 activation just created. Without a workaround, `register-nix-paths` fails on
`nix-env --set /run/current-system` (dangling) and every downstream service collapses.

The template applies two fixes:

1. **`boot.postBootCommands`** — loads the nix store db and sets the system profile *before* systemd starts (while
   `/run/current-system` still exists). This consumes `/nix-path-registration`, so the upstream `register-nix-paths`
   service is correctly skipped via its `ConditionPathExists`.
1. **`systemd.tmpfiles.rules`** — recreates the `/run/current-system` and `/run/booted-system` symlinks (pointing
   through the profile) after systemd's tmpfs wipe, via `systemd-tmpfiles-setup.service` early in boot.

Additionally, the proxmox-lxc module sets `manageNetwork = false` → `useNetworkd = true`, but ships no `.network` file
for eth0. The template adds a DHCP `.network` so networkd brings the interface up and the container is reachable for the
first `nixos-rebuild`.
