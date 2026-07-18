# Homelab provisioning (OpenTofu)

Declarative provisioning for the homelab's Proxmox LXC containers. Tofu **creates and sizes** containers on the Proxmox
host; each container's NixOS config (under `hosts/<name>/`) owns its OS, services, and static IP.

## Layout

| File           | Purpose                                                                    |
| -------------- | -------------------------------------------------------------------------- |
| `versions.tf`  | Pins OpenTofu (`>= 1.6`) and the `bpg/proxmox` provider (`~> 0.111`).      |
| `provider.tf`  | Configures the `proxmox` provider; reads credentials from the environment. |
| `variables.tf` | Provisioning inputs — node, datastores, bridge, template, per-host sizing. |
| `edge.tf`      | The `edge` ingress LXC container resource.                                 |
| `cache.tf`     | The `cache` LAN Nix binary cache LXC container resource.                   |
| `runners.tf`   | The `runners` CI build-host LXC container resource.                        |
| `storage.tf`   | ZFS pool registration + encrypted-dataset unlock (#166).                   |
| `.gitignore`   | Keeps plaintext state and the provider cache out of git.                   |

Wrapper: [`scripts/tofu-sops.fish`](../scripts/tofu-sops.fish) — sources credentials and manages encrypted state.

## Prerequisites

- `tofu`, `sops`, and `age` on PATH. On p51 these are installed system-wide (p51's `home.nix`), so no devshell is
  needed. On a host without them, enter the repo devshell first: `nix develop`.
- Your age/YubiKey key configured for SOPS (the repo's existing `.sops.yaml` workflow).
- A Proxmox **API token** (not a password) for a user that can create LXCs, e.g. `root@pam!tofu`.

## The Proxmox API token secret

Credentials are never written to the working tree. They live in SOPS and are decrypted into the environment at
plan/apply time. Add the two keys interactively (requires your YubiKey/age key):

```fish
sops secrets/<host>/secrets.yml
```

with these two keys:

```yaml
proxmox_ve_endpoint: "https://<proxmox-host>:8006/"
proxmox_ve_api_token: "root@pam!tofu=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

The `bpg/proxmox` provider reads `PROXMOX_VE_ENDPOINT` and `PROXMOX_VE_API_TOKEN` natively; the wrapper exports exactly
those from the decrypted secret.

## Proxmox API token permissions

The API token authenticates via a Proxmox role (`TerraformProvision`) scoped to exactly the privileges Tofu needs. On a
fresh Proxmox host, recreate the role and assign it to the token's group:

```bash
pveum role add TerraformProvision -privs \
  "VM.Allocate,VM.Audit,VM.Config.CPU,VM.Config.Memory,VM.Config.Disk,VM.Config.Network,VM.Config.Options,VM.Config.HWType,Datastore.Allocate,Datastore.Audit,Datastore.AllocateSpace,Sys.Audit,Sys.Modify,SDN.Use,VM.PowerMgmt"
```

| Privilege                                          | Used for                                                                     |
| -------------------------------------------------- | ---------------------------------------------------------------------------- |
| `VM.Allocate`, `VM.Audit`                          | Create, read, destroy LXC containers                                         |
| `VM.Config.CPU/Memory/Disk/Network/Options/HWType` | Configure container resources                                                |
| `VM.PowerMgmt`                                     | Start / stop containers (the `started` flag, plus shutdown during update)    |
| `Datastore.Allocate`                               | Register the `hdd-zfs` pool as Proxmox storage                               |
| `Datastore.AllocateSpace`, `Datastore.Audit`       | Allocate and read container disk volumes                                     |
| `Sys.Audit`                                        | Read node metadata for provider node discovery                               |
| `Sys.Modify`                                       | Set a container's network config (`initialization.ip_config`) at create time |
| `SDN.Use`                                          | Attach the container NIC to the `vmbr0` bridge (SDN-gated on Proxmox 8+)     |

> Already have the role from an earlier setup? Recreate it with the full privilege set in one shot:
>
> ```bash
> pveum role modify TerraformProvision -privs \
>   "VM.Allocate,VM.Audit,VM.Config.CPU,VM.Config.Memory,VM.Config.Disk,VM.Config.Network,VM.Config.Options,VM.Config.HWType,Datastore.Allocate,Datastore.Audit,Datastore.AllocateSpace,Sys.Audit,Sys.Modify,SDN.Use,VM.PowerMgmt"
> ```
>
> The role was originally scoped for an older module shape and a pre-SDN Proxmox. Four privileges were added as the
> module and Proxmox evolved — each surfaces as a sequential `HTTP 403` at apply time, so add them all up front rather
> than discovering them one-by-one:
>
> | Privilege      | When it became necessary                                                                    |
> | -------------- | ------------------------------------------------------------------------------------------- |
> | `Sys.Modify`   | Containers booting on a static IP at create time (`initialization.ip_config`)               |
> | `SDN.Use`      | Proxmox 8+ gating bridge attachment behind SDN permissions                                  |
> | `VM.PowerMgmt` | Tofu managing the `started` flag (start/stop/shutdown of a running container during update) |

## Usage

Always go through the wrapper so credentials and state stay encrypted. The wrapper resolves its own paths from its
location, so you can call it by path from anywhere — no need to `cd` into the repo or `tofu/`:

```fish
scripts/tofu-sops.fish init    # downloads the bpg/proxmox provider
scripts/tofu-sops.fish plan    # authenticates to Proxmox
scripts/tofu-sops.fish apply
```

Any `tofu` subcommand/flags pass straight through: `scripts/tofu-sops.fish state list`, etc.

## State: SOPS-encrypted, committed to git

State is the recovery source, so it is version-controlled and mirrored to GitHub — but only in encrypted form.

- **Committed:** `tofu/terraform.tfstate.enc` (SOPS/age-encrypted).
- **Ignored:** plaintext `terraform.tfstate` / `*.backup` (see `.gitignore`).

The wrapper handles the lifecycle automatically on every run:

1. **decrypt-on-read** — `terraform.tfstate.enc` → plaintext `terraform.tfstate` before invoking `tofu`.
1. runs `tofu`.
1. **encrypt-on-write** — re-encrypts the updated state back to `terraform.tfstate.enc`, then shreds the plaintext.

If the wrapper aborts after `apply` but before re-encrypting, it prints the plaintext state path and exits non-zero —
encrypt it (`sops --encrypt tofu/terraform.tfstate > tofu/terraform.tfstate.enc`) before committing, and never commit
the plaintext.

After a successful run, commit the encrypted state alongside any config changes:

```fish
git add tofu/terraform.tfstate.enc tofu/*.tf
```

## The LXC template

Containers boot from a minimal NixOS LXC template:

```fish
nix build .#lxc-template
ls -la result/   # proxmox-lxc tarball
```

Register the built tarball as a Proxmox CT template, then reference it by a stable name from the container resource. See
[`../templates/README.md`](../templates/README.md) for the registration steps and the template name.

## Container hostname

Each container passes a `hostname` to the shared LXC module (`homelab-edge`, `homelab-cache`, …), which becomes the
Proxmox CT hostname shown in the Proxmox UI and `pct list`. Without it Proxmox falls back to the default `CT<vmid>`
(e.g. `CT107`, `CT108`). This is the **Proxmox-side** label only — NixOS still owns the in-container hostname via
`networking.hostName` from the first `nixos-rebuild switch` onward.

The name is applied at **create time**. Because the module keeps `initialization` in `lifecycle.ignore_changes` (so a
running container's networking/hostname is never reconciled out from under NixOS), `tofu apply` does **not** rename an
already-running container. To rename an existing one without a destroy/recreate, set it once over root SSH:

```fish
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@<proxmox-host> 'pct set <ctid> --hostname <name>'
# e.g. pct set 107 --hostname homelab-edge   (edge)
#      pct set 108 --hostname homelab-cache  (cache)
```

A [destroy/recreate](#destroy--recreate-a-container-from-code) also picks up the new name, since the hostname is set on
create.

## ZFS pool + encrypted dataset

A ZFS mirror of the two 14.6 TB HDDs on the Proxmox host provides bulk storage and two encrypted datasets:
`hdd-zfs/keys` for per-host key material and `hdd-zfs/data` for bulk service data (today: `hdd-zfs/data/forge`, the
Forgejo repository root). Each is its own encryptionroot, unlocked with the same SOPS-held passphrase. Each subdirectory
under an encrypted dataset mounts exclusively into its own container.

### Operator steps (one-time on the Proxmox host)

The `bpg/proxmox` provider can register an existing pool as Proxmox storage but **cannot** create one from disks. The
pool itself is a one-time operator step, like the LXC template upload. Run on the Proxmox host:

```bash
ssh root@<proxmox-host>

# Verify the two HDDs are present and empty.
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT /dev/sda /dev/sdb
wipefs /dev/sda /dev/sdb        # should print nothing

# Mirror pool + encrypted dataset (prompts for passphrase — store it in SOPS, see below).
zpool create -o ashift=12 hdd-zfs mirror sda sdb
zfs create -o encryption=on -o keyformat=passphrase -o keylocation=prompt \
  -o mountpoint=/hdd-zfs/keys hdd-zfs/keys

# Per-host subdirectories — each mounted into its own container only.
zfs create hdd-zfs/keys/cache
zfs create hdd-zfs/keys/edge

# Bulk-data tree — separate encryptionroot, SAME passphrase as hdd-zfs/keys.
zfs create -o encryption=on -o keyformat=passphrase -o keylocation=prompt \
  -o mountpoint=/hdd-zfs/data hdd-zfs/data
zfs create hdd-zfs/data/forge
```

### Passphrase in SOPS

Add the passphrase alongside the existing Proxmox API credentials in `secrets/<runner>/secrets.yml`:

```yaml
proxmox_ve_endpoint:    "https://<proxmox-host>:8006/"
proxmox_ve_api_token:   "root@pam!tofu=<uuid>"
homelab-zfs-passphrase: "<openssl-rand-base64-32>"
```

`scripts/tofu-sops.fish` exports it as `TF_VAR_homelab_zfs_passphrase` on every run (the SOPS key uses hyphens, the TF
variable uses underscores because `TF_VAR_*` names must be shell-safe). If the key is absent (early provisioning, before
the dataset exists) the wrapper prints a note and skips the export — apply still works for resources that don't need it.

### What `tofu apply` does

1. **`proxmox_storage_zfspool.hdd_zfs`** registers the pool as Proxmox storage so container `disk`/`mount_point` blocks
   can reference `datastore_id = "hdd-zfs"`.
1. **`null_resource.zfs_keys_unlock`** SSHes into the Proxmox node and runs `zfs load-key` + `zfs mount` for both
   encrypted datasets (`hdd-zfs/keys` and `hdd-zfs/data`, children included) with idempotency guards. On first apply the
   datasets are already unlocked + mounted (the operator just created them), so the guards skip both steps.
1. Each container's `initialization.ip_config` records its static IP in Proxmox metadata. The **template** still DHCPs
   for bootstrap (see [Bootstrap](#bootstrap-template-container--flake-host)); the per-host flake config takes over the
   static address after the first `nixos-rebuild switch`. The `initialization` block is in `lifecycle.ignore_changes`,
   so NixOS owns networking from the first `switch` onward.
1. **`null_resource.bind_mounts`** (per container with `mount_points`) attaches the per-host `hdd-zfs/keys/<host>/` bind
   mount over root SSH (see [Per-container key persistence mount](#per-container-key-persistence-mount)). The dataset is
   already unlocked host-wide, so a destroy/recreate needs no password — the persisted SSH host key is remounted and the
   committed `.sops.yaml` recipient stays valid.

### Reboot-relock

After a Proxmox host reboot both encrypted datasets re-lock. Unlock them manually from the Tofu runner using the
SOPS-held password (one decrypt, one `ssh` per encryptionroot):

```fish
set -l pass (sops -d --extract '["homelab-zfs-passphrase"]' secrets/<runner>/secrets.yml)
echo $pass | ssh root@<proxmox-host> 'zfs load-key hdd-zfs/keys && zfs mount hdd-zfs/keys && zfs mount hdd-zfs/keys/cache && zfs mount hdd-zfs/keys/edge && zfs mount hdd-zfs/keys/forge && zfs mount hdd-zfs/keys/runners'
echo $pass | ssh root@<proxmox-host> 'zfs load-key hdd-zfs/data && zfs mount hdd-zfs/data && zfs mount hdd-zfs/data/forge'
```

Keep it to **one `zfs load-key` per `ssh` invocation**: `load-key` reads the passphrase from stdin through buffered
stdio, so a second `load-key` chained in the same remote shell finds its stdin already drained and fails. Mount the
parent before its children — each child mounts under the parent's path. Add another `&& zfs mount <dataset>/<host>`
clause to the matching line when new per-host subdirectories come online.

### Per-container key persistence mount

Each container that needs to survive destroy/recreate with its sops-nix age identity intact bind-mounts its own per-host
subdirectory of the encrypted dataset into the container at `/persist`. The shared LXC module (`modules/lxc/main.tf`)
exposes an optional `mount_points` variable; a container enables persistence by passing one entry mapping the host path
to `/persist`:

```hcl
module "cache" {
  source = "./modules/lxc"
  # ...
  mount_points = [
    {
      volume = "/hdd-zfs/keys/cache"   # host path on the unlocked dataset
      path   = "/persist"              # in-container mount point
      owner  = "100000:100000"         # chown host-side to container-root (subuid base)
    }
  ]
}
```

**Bind mounts are applied via root SSH, not as a native `mount_point` block.** Proxmox restricts bind mounts to the
`root@pam` user — the `root@pam!tofu` API token the provider authenticates as is rejected with HTTP 403
(`mount point type bind is only allowed for root@pam`). The module therefore emits a `null_resource.bind_mounts` that
SSHes into the Proxmox node as `root@pam` (the `id_ed25519_tofu` key from #166) and runs `pct set -mpN`.
`replace_triggered_by` re-runs it whenever the container is (re)created, so the mount is re-attached automatically on
each rebuild — the underlying host paths (encrypted-dataset subdirectories) survive recreate, so the keys persist.
Storage-backed Proxmox volumes were ruled out: they are destroyed together with the container, defeating the persistence
goal.

The NixOS side (`services.sshHostKeyPersistence.enable` in
[`hosts/cache/configuration.nix`](../hosts/cache/configuration.nix), backed by
[`modules/ssh-host-key-persistence/`](../modules/ssh-host-key-persistence/)) points `services.openssh.hostKeys` and
`sops.age.sshKeyPaths` at `/persist/ssh/ssh_host_ed25519_key`, so the key — and the derived age identity — lives on the
encrypted dataset and survives recreate with no `sops updatekeys`. See
[`hosts/cache/README-cache.md`](../hosts/cache/README-cache.md) for the first-ever bootstrap, live-host migration, and
the full [rebuild procedure](../hosts/cache/README-cache.md#rebuilding-the-cache-host).

Per-host isolation is preserved: each container's `mount_points` targets only its own `hdd-zfs/keys/<host>/`
subdirectory, so the cache container cannot read the edge container's key. Both `cache` and `edge` enable persistence; a
container that needs none simply omits `mount_points` and gets no `null_resource`.

The same mechanism carries bulk data mounts: `forge` adds a second entry mapping `hdd-zfs/data/forge` to
`/var/lib/forgejo-repos`, so the Forgejo repository root lives encrypted on the HDD pool while the container rootfs
(Forgejo state dir + PostgreSQL) stays on NVMe. Note that adding a mount to an **already-running** container is not
picked up by `tofu apply` alone — the `bind_mounts` provisioner only re-runs on container replacement, and its guard
keys off the first mount (`/persist`) already being attached. Either attach it once by hand over root SSH
(`pct stop 109 && pct set 109 -mp1 /hdd-zfs/data/forge,mp=/var/lib/forgejo-repos && pct start 109`) or
[destroy/recreate](#destroy--recreate-a-container-from-code) the container.

A mount is chowned host-side only when its `mount_points` entry sets an `owner` (`"uid:gid"` in the Proxmox host
namespace). This is required because on an unprivileged LXC the host root (uid 0) is not mapped into the guest: a fresh
host-root-owned dataset is squashed to `nobody` (`65534`) inside the container, and the in-container service **cannot
chown a host-owned bind mount itself** (`chown: Operation not permitted`, even as container-root). The owner is the
subuid base (`100000`) plus the in-container uid/gid — `"100000:100000"` for the `/persist` key mount so
container-root's `sshd`/`sops-nix` can read the host key, and `"100996:100995"` for the forge repo dataset so the
`forgejo` service can create repositories under it. A mount that omits `owner` keeps its host ownership — correct for
the NFS-backed NAS backup mount, whose ownership is fixed on the NAS side (recursively chowning it to a subuid would
misown it).

### NAS-backed backup mount

`forge` runs a daily restic backup to the Synology NAS ([`hosts/forge/restic.nix`](../hosts/forge/restic.nix)). Because
`forge` is an **unprivileged** LXC it cannot mount NFS from inside the guest — the kernel denies the `mount()` syscall
(`mount.nfs: Operation not permitted`, exit 32) for any share or NFS version, even ones a bare-metal host mounts fine.
So the **Proxmox host** mounts the NAS and bind-mounts it into the container; restic sees a plain local directory and
the NFS lives entirely on the privileged host.

**Operator step (one-time on the Proxmox host):** mount the Synology export at the host path the container maps in
(`/mnt/nas-forge-backup`). Key the NFS export to the Proxmox host's LAN IP (not `forge.fileshare.se`, which resolves to
edge). A persistent systemd/fstab entry on pve:

```bash
# /etc/fstab on pve — the NAS export the container's third mount_points entry maps in.
fileshare.local:/volume2/forge-backup  /mnt/nas-forge-backup  nfs  nfsvers=4,_netdev,x-systemd.automount,noauto  0 0
```

Then `systemctl daemon-reload && mount /mnt/nas-forge-backup`. The container's `mount_points` third entry maps
`/mnt/nas-forge-backup → /var/lib/forgejo-backup-repo`; restic's repository is `…/restic` under it. The mount is
attached the same way as the others (over root SSH on create/recreate; hand-attach with
`pct set 109 -mp2 /mnt/nas-forge-backup,mp=/var/lib/forgejo-backup-repo` on an already-running container). After a pve
reboot the NAS remounts via its own `x-systemd.automount`, independent of the encrypted-dataset relock.

**Set the Synology export squash to "Map all users to admin".** restic runs as the container's root, which on an
unprivileged LXC is host uid `100000` (the subuid base) once it crosses the bind mount to NFS. A default (root-only /
"No mapping") export lets *pve*'s real uid 0 write but squashes the container's uid `100000` to a denied anon — restic
then fails to even `stat`/`mkdir` the repo (`permission denied`) despite a `0777` directory, because the NAS denies at
the NFS layer, not on the Unix mode. "Map all users to admin" writes every incoming request as the NAS admin, so the
container's uid-`100000` writes land correctly. The share is single-purpose (forge's backup only), so all-squash has no
downside here. This is a NAS-side setting; no config in this repo encodes it.

### Cache rootfs on the HDD pool

The cache container is the one host whose rootfs (and therefore its `/nix/store`) deliberately lives on the bulk
`hdd-zfs` pool rather than the NVMe `local-lvm` pool. The store *wants* capacity — it pre-warms every host's full
closure plus upstream artifacts — and the cache does no latency-sensitive work, so spinning disk is fine. The whole
rootfs lives on the HDD pool rather than a split mount (small NVMe rootfs + large HDD `/nix`): no `fileSystems`
split-mount, no "is `/nix/store` mounted before nix-serve starts?" ordering.

The mechanism is a single per-instance datastore override in [`cache.tf`](cache.tf):

```hcl
module "cache" {
  source = "./modules/lxc"
  # ...
  # All other containers inherit the default (var.container_datastore = "local-lvm");
  # the cache overrides to put its whole rootfs on the HDD pool.
  container_datastore = var.hdd_zfs_storage_id
}
```

The shared module's `disk { datastore_id = var.container_datastore }` consumes whatever datastore each instance passes
in, so the override is the whole change — no module edit needed. `cache_disk_size` (default `512` GB) is sized for bulk
HDD capacity; ZFS is thin-provisioned, so the volume only consumes what is written.

#### Moving a container's rootfs between datastores

Proxmox cannot relocate a running container's rootfs between datastores in place, so a **destroy/recreate** is what puts
the rootfs on a different pool — `tofu apply` does not move it on an existing container:

```fish
scripts/tofu-sops.fish destroy -target module.cache
scripts/tofu-sops.fish apply
```

The destroy **wipes `/nix/store`** (the store lives on the rootfs, which is deleted with the container). The store
re-warms on the next [`cache-prewarm` timer run](../hosts/cache/README-cache.md#pre-warm) — the first run pulls every
closure from the public caches and is slow; later runs are incremental. The SSH host key survives the recreate via the
[`/persist` key mount](#per-container-key-persistence-mount), so no `sops updatekeys` is needed. After the recreate,
follow the [rebuild procedure](../hosts/cache/README-cache.md#rebuilding-the-cache-host) to converge the container back
onto its flake host config.

## Nesting requirement (systemd 256+)

systemd 256+ (nixpkgs 26.05) attempts to mount a private tmpfs for each service's credential store when spawning it.
Proxmox's LXC AppArmor profile denies that mount in a container **without `nesting`** → every core service (journald,
networkd, tmpfiles-setup, resolved…) dies with `exit 243/CREDENTIALS` → cascading boot failure
([systemd#41311](https://github.com/systemd/systemd/issues/41311),
[nixpkgs#529888](https://github.com/NixOS/nixpkgs/issues/529888)).

The shared LXC module defaults `nesting = true` and `unprivileged = true`. **Do not override either to `false`** unless
you also deploy a credential-stripping generator (see Debian's `lxc.generator`). Both `cache` and `edge` use the
defaults; `edge` previously overrode them to `false` and failed to boot.

## Bootstrap: template container → flake host

`apply` creates the container **running** (`started = true`) from the base template. The template boots with DHCP,
`nesting=true`, and the `id_ed25519_tofu` key baked into root's `authorized_keys` — so no manual key injection or
`pct start` is needed. The container must be converged onto its real flake host config once, by hand.

Two approaches:

- **`--target-host`** (no push needed): build on a machine with the full nix store (e.g. p51) and push the closure over
  SSH. Use this when `main` has uncommitted or unpushed changes.
- **clone + rebuild** (requires push): SSH in, `git clone`, `nixos-rebuild switch`. Use this when the repo is on GitHub
  and the working tree is clean.

Both approaches converge a **fresh** container once, from `main` or the operator's working tree — on a brand-new forge
the gated `blessed` ref may not exist yet (the gate creates it on its first passing run). Every update after bootstrap
instead tracks `blessed`: see [Ongoing host updates](#ongoing-host-updates-track-blessed).

### Option A: `--target-host` (recommended for unpushed work)

```fish
# 1. Find the DHCP lease the template booted with (iproute2 is in the template):
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@<proxmox-host> \
  'pct exec <ctid> -- /run/current-system/sw/bin/ip -4 -br addr show eth0'

# 2. Build + push the closure + activate (from the repo root on p51):
set lease <dhcp-addr-from-step-1>
sudo env NIX_SSHOPTS="-i ~/.ssh/id_ed25519_tofu" \
  nixos-rebuild switch --flake .#nixos-<host> --target-host root@$lease
```

The `switch` stops the template's networkd (DHCP) and starts the host config's scripted networking (static IP). The SSH
connection to the DHCP address **drops mid-activation** — that is expected, not a hang. The new generation is already
set as the system profile, so reboot to complete the activation cleanly:

```fish
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@<proxmox-host> 'pct reboot <ctid>'
```

Reconnect on the static IP (the DHCP lease is gone):

```fish
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@<static-ip>
hostname  # → <host>, e.g. "edge"
```

For `edge` the static IP is `192.168.2.107` / gateway `192.168.2.1`, as declared in
[`../hosts/edge/configuration.nix`](../hosts/edge/configuration.nix).

### Option B: clone + rebuild (requires the repo on GitHub)

```fish
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@<dhcp-addr>
git clone https://github.com/<owner>/nixos-config.git && cd nixos-config
sudo nixos-rebuild switch --flake .#nixos-<host>
```

Reconnect on the static IP after the switch. The bootstrap clone builds from `main` (the clone's default HEAD); once the
host is converged, ongoing updates switch the clone to the forge remote and the `blessed` ref — see
[Ongoing host updates](#ongoing-host-updates-track-blessed).

## Ongoing host updates: track `blessed`

Bootstrap is the only time the pull-based path builds from `main`. From then on, a host only ever deploys **gated**
updates by tracking the `blessed` ref — the strict trailing pointer inside `main`'s history that the
[gate](../hosts/runners/README-runners.md#the-gate-forgejoworkflowsgateyaml) advances to each commit that passed
validation. The gate advances `blessed` on the forge repo, so the host's clone must point at the forge — switch a
bootstrap-era GitHub clone once with `git remote set-url origin https://forge.fileshare.se/jonatan/nixos-config.git`.
Because `blessed` only ever fast-forwards (the gate never forces), an update is a plain ff pull + switch:

```fish
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@<static-ip>
cd nixos-config
git fetch && git checkout blessed && git pull --ff-only
sudo nixos-rebuild switch --flake .#nixos-<host>
```

It is normal for `blessed` to lag `main`: a commit that did not go through the gate intentionally leaves `blessed`
behind, and hosts stay on the last validated state until the next gated update advances it. The push-based path (Option
A) is unchanged — it deploys whatever the operator builds, and remains the tool for unpushed or host-specific work.
Rolling `blessed` back after a bad update is documented in
[`README-forge.md` "Rolling back `blessed`"](../hosts/forge/README-forge.md#rolling-back-blessed); hosts recover fast
because the previous closure is still served by the LAN cache
([`README-cache.md` "Ongoing updates and rollback"](../hosts/cache/README-cache.md#ongoing-updates-and-rollback)).

## Destroy / recreate a container from code

A container is disposable: it can be destroyed and rebuilt from this repo alone, because the resource definition is in
`tofu/` and its OS/services live in `hosts/<name>/`. Destroy one container without touching the others by targeting it:

```fish
# destroy just the edge container (leave others untouched)
scripts/tofu-sops.fish destroy -target module.edge

# recreate it (boots running with nesting+DHCP), then bootstrap per above
scripts/tofu-sops.fish apply -target module.edge
```

`apply` re-creates the container from the same template and sizing, **running** (`started = true`); follow the
[bootstrap](#bootstrap-template-container--flake-host) to converge it onto its flake host config. The result is the same
working host — same hostname, static IP, and services — because every input is code.

The encrypted state round-trips automatically through the wrapper (decrypt → `tofu` → re-encrypt → shred plaintext), so
after a destroy/recreate cycle commit the updated encrypted state:

```fish
git add tofu/terraform.tfstate.enc
git status   # confirm: no plaintext terraform.tfstate / *.backup / secrets staged
```

## Recovery from a clean checkout

The whole provisioning layer rebuilds from a fresh clone on top of a fresh Proxmox — the encrypted state committed to
GitHub is the single recovery source. Nothing beyond this repo and your YubiKey/age key is required.

1. **Clone the repo** on a machine with `tofu`, `sops`, and `age` (p51 has them system-wide; elsewhere `nix develop`
   first) and your age/YubiKey key configured for SOPS.

   ```fish
   git clone https://github.com/JHilmarch/nixos-config.git && cd nixos-config
   ```

1. **Register the LXC template** on the fresh Proxmox host under the stable name (see
   [`../templates/README.md`](../templates/README.md)) so the container resources resolve.

1. **Provision the ZFS pool + encrypted dataset** per [ZFS pool + encrypted dataset](#zfs-pool--encrypted-dataset) —
   same one-time operator step on the new Proxmox host, and add `homelab-zfs-passphrase` to
   `secrets/<runner>/secrets.yml`.

1. **Ensure the Proxmox API token secret** exists for the host you're running from (`secrets/<host>/secrets.yml` with
   `proxmox_ve_endpoint` + `proxmox_ve_api_token` — see [The Proxmox API token secret](#the-proxmox-api-token-secret)).

1. **Init + apply through the wrapper.** It decrypts the committed state (`terraform.tfstate.enc`) and the credentials,
   runs `tofu`, and re-encrypts state on exit — so the recovered state is exactly the mirrored one:

   ```fish
   scripts/tofu-sops.fish init
   scripts/tofu-sops.fish apply
   ```

1. **Bootstrap each recreated container** onto its flake host config per the
   [bootstrap section](#bootstrap-template-container--flake-host).

Because state is version-controlled (encrypted) and mirrored to GitHub, recovery never depends on any machine-local
file: clone → decrypt (state + creds) via SOPS → `tofu init/apply` → bootstrap.
