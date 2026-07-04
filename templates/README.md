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

## `lxc-base.nix` — the homelab LXC template image

`lxc-base.nix` is deliberately **standalone**: it does *not* import the host chain above, so it can be built from a
clean checkout and consumed by OpenTofu as a Proxmox CT template.

It is a minimal base that only needs to:

1. boot as a privileged Proxmox LXC,
1. come up on the network (DHCP; the per-host flake config takes over static addressing),
1. accept key-based SSH, and
1. carry `nix` + `git` so `nixos-rebuild switch --flake .#<host>` can take over — after which this base is fully
   superseded by the real host config.

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
