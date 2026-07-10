---
name: scaffold-lxc-host
description: 'Scaffold a new homelab Proxmox LXC host (like edge or cache) end to end — hosts/<name>/, the flake nixosConfiguration, the tofu container resource, SOPS + /persist key material, and the README. Use when adding a new homelab container, provisioning another LXC service, or "add an lxc host". Triggers: "new lxc host", "scaffold lxc", "add a homelab container", "another proxmox lxc".'
---

# Scaffold a new homelab LXC host

## Overview

Every homelab Proxmox LXC (`edge`, `cache`, and future ones) shares one base:
[`templates/proxmox-lxc.nix`](../../../templates/proxmox-lxc.nix). It already provides garbage collection, DNS
(`resolved` + `useHostResolvConf = false`), LAN nameservers/gateway defaults, `openssh.openFirewall`, SSH host-key
persistence, unprivileged+nesting defaults, and SOPS wiring (via `server.nix`). A new host therefore only declares its
**unique delta**: hostname, static IP, `stateVersion`, its workload, and its provisioning inputs.

**Core principle:** import the template, then add only what makes this host different. If you find yourself re-declaring
`resolved`, `nameservers`, `nix.gc`, `sshHostKeyPersistence`, or `privileged`, stop — the template already did it.

**Announce at start:** "I'm using the scaffold-lxc-host skill to add the `<name>` LXC host."

## When to use

- Adding a new Proxmox LXC to the homelab (a new service container, jump host, runner, etc.).
- Any request like "add an lxc host", "scaffold a new homelab container", "provision another LXC".
- **Do NOT use** for desktop/laptop hosts (orion, p51) — those use the `desktop.nix` chain, not `proxmox-lxc.nix`.

## What the template already gives you (do NOT re-declare)

From [`templates/proxmox-lxc.nix`](../../../templates/proxmox-lxc.nix) via its `server.nix` → `common.nix` chain:

| Concern                   | Provided by template                                                       |
| ------------------------- | -------------------------------------------------------------------------- |
| Garbage collection        | `nix.gc` monthly `--delete-older-than 30d`, niced/idle serviceConfig       |
| DNS                       | `services.resolved.enable`, `networking.useHostResolvConf = false`         |
| LAN nameservers + gateway | `["192.168.2.1"]` / `"192.168.2.1"` via `mkDefault` (override per host)    |
| SSH                       | `openssh` (from `server.nix`) + `openFirewall` + `sshHostKeyPersistence`   |
| Unprivileged + nesting    | `proxmoxLXC.privileged = mkDefault false` (nesting is a tofu feature flag) |
| SOPS                      | `server.nix` sets `defaultSopsFile = secrets/<hostname>/secrets.yml`       |
| LAN binary cache client   | `common.nix` imports `nix-cache-client.nix`                                |
| systemd v260 `/run` fix   | inherited by the running config; the base image handles first boot         |

So a new host's `configuration.nix` is typically ~30 lines.

## Steps

Work in an isolated worktree (use the `using-git-worktrees` skill). Replace `<name>` with the hostname (e.g. `forge`)
and pick a free static IP + CT id.

### 1. Create `hosts/<name>/configuration.nix`

Model on [`hosts/cache/configuration.nix`](../../../hosts/cache/configuration.nix) (simplest) or
[`hosts/edge/configuration.nix`](../../../hosts/edge/configuration.nix) (with extra modules). Minimum shape:

```nix
{
  config,
  pkgs,
  lib,
  username,
  hostname,
  self,
  ...
}: {
  imports = [
    "${self}/templates/proxmox-lxc.nix"
    # + any workload modules, e.g. "${self}/modules/nginx-ingress/default.nix"
  ];

  networking = {
    hostName = hostname;
    useDHCP = false;
    interfaces.eth0.ipv4.addresses = [
      {
        address = "192.168.2.<N>";
        prefixLength = 24;
      }
    ];
  };

  # --- this host's workload only ---
  # services.<whatever>.enable = true;

  system.stateVersion = "26.05"; # pin to the current release at creation; never bump later
}
```

Do **not** add `nameservers`, `defaultGateway`, `resolved`, `openFirewall`, `nix.gc`, `sshHostKeyPersistence`, or
`proxmoxLXC.privileged` unless this host genuinely differs from the LAN default — the template covers them.

### 2. Create `hosts/<name>/home.nix`

Copy [`hosts/cache/home.nix`](../../../hosts/cache/home.nix) verbatim (fish + lsd/fzf/zoxide/broot/starship). Set
`home.stateVersion` to match `system.stateVersion`.

### 3. Wire the flake `nixosConfiguration`

In [`flake.nix`](../../../flake.nix), add a `nixos-<name>` attribute under `nixosConfigurations`. Copy the `nixos-cache`
block — it is the canonical LXC shape (sops-nix + home-manager modules, `functions` in `specialArgs`, no
`pkgs-unstable`):

```nix
nixos-<name> = let
  system = "x86_64-linux";
  specialArgs = {
    inherit inputs self;
    username = "jonatan";
    hostname = "<name>";
    functions = import ./functions {
      pkgs = import inputs.nixpkgs {inherit system;};
    };
  };
in
  inputs.nixpkgs.lib.nixosSystem {
    specialArgs = specialArgs;
    modules = [
      {nixpkgs.hostPlatform.system = system;}
      ./hosts/<name>/configuration.nix
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.extraSpecialArgs = specialArgs;
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "hm-backup";
        home-manager.users.${specialArgs.username} = import ./hosts/<name>/home.nix;
      }
    ];
  };
```

The flake attribute is `nixos-<name>`; the `hostname` is bare `<name>`. Both `edge` and `cache` follow this split.

### 4. Add the tofu container resource

Create `tofu/<name>.tf` modelled on [`tofu/edge.tf`](../../../tofu/edge.tf) (add a `mount_points` `/persist` entry only
if the host needs SOPS-key persistence across recreate — see step 5), and per-host sizing variables in
[`tofu/variables.tf`](../../../tofu/variables.tf) (`<name>_vm_id`, `<name>_cores`, `<name>_memory`, `<name>_disk_size`).
Keep `unprivileged = true` and `nesting = true` — modern systemd needs nesting or the container never boots (see
[`tofu/README.md` "Nesting requirement"](../../../tofu/README.md#nesting-requirement-systemd-256)).

### 5. Secrets + key persistence (only if the host needs SOPS)

The template enables `sshHostKeyPersistence`, which expects a `/persist` bind mount. If this host reads SOPS secrets:

1. Create the encrypted ZFS subdirectory on the Proxmox host: `zfs create hdd-zfs/keys/<name>`.
1. Add the `mount_points` `/persist` entry in `tofu/<name>.tf` (copy edge's block).
1. Create `secrets/<name>/secrets.yml` and add the `&<name>` age recipient to `.sops.yaml` — the recipient is derived
   from the persisted SSH host key **after first boot** (see the first-ever-bootstrap flow in
   [`hosts/cache/README-cache.md`](../../../hosts/cache/README-cache.md#first-ever-bootstrap-once-per-host-lifetime)).

If the host needs **no** secrets, it still boots fine — `sshHostKeyPersistence` just persists the host key onto
`/persist`; omit the mount and it regenerates on recreate, which is harmless without SOPS.

### 6. Write `hosts/<name>/README-<name>.md`

Model on [`README-edge.md`](../../../hosts/edge/README-edge.md) /
[`README-cache.md`](../../../hosts/cache/README-cache.md): what the host does, its static IP + CT id, and any
host-specific bootstrap. Add the host to the flake target list in the top-level [`README.md`](../../../README.md).

### 7. Verify

Use the `verify-flake` skill to check the new `nixos-<name>` host — it walks the staged eval → `nix flake check` → build
gate. A new host is a non-trivial change, so run it through the build gate.

### 8. Provision + bootstrap

Follow [`tofu/README.md`](../../../tofu/README.md): `scripts/tofu-sops.fish apply -target module.<name>`, then converge
the container onto its flake config via `--target-host` (see the bootstrap section). Commit the encrypted state.

## Checklist

- [ ] `hosts/<name>/configuration.nix` — imports `templates/proxmox-lxc.nix`, declares only the host delta
- [ ] `hosts/<name>/home.nix` — copied from cache, `stateVersion` matched
- [ ] `flake.nix` — `nixos-<name>` added (copied from `nixos-cache` block)
- [ ] `tofu/<name>.tf` + sizing vars in `tofu/variables.tf`
- [ ] `secrets/<name>/` + `.sops.yaml` recipient (only if the host uses SOPS)
- [ ] `hosts/<name>/README-<name>.md` + entry in top-level README
- [ ] `verify-flake`: eval + `nix flake check` + build gate green
- [ ] provisioned + bootstrapped per `tofu/README.md`, encrypted state committed

## Red flags

**Never:**

- Re-declare `nix.gc`, `resolved`, `nameservers`, `defaultGateway`, `openFirewall`, `sshHostKeyPersistence`, or
  `proxmoxLXC.privileged` in the host — the template owns them; only override a specific one when the host genuinely
  differs from the LAN default.
- Set `unprivileged = false` or `nesting = false` in tofu — the container will fail to boot (systemd 256+ credential
  mounts).
- Bump `stateVersion` on an existing host — pin it once at creation.
- Edit `secrets/` or `.sops.yaml` without the operator's YubiKey present.

**Always:**

- Import `templates/proxmox-lxc.nix` first and keep the host config to its unique delta.
- Match `home.stateVersion` to `system.stateVersion`.
- Verify with the `verify-flake` skill before provisioning.
