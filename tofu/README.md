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
  "VM.Allocate,VM.Audit,VM.Config.CPU,VM.Config.Memory,VM.Config.Disk,VM.Config.Network,VM.Config.Options,VM.Config.HWType,Datastore.Allocate,Datastore.Audit,Datastore.AllocateSpace,Sys.Audit"
```

| Privilege                                          | Used for                                       |
| -------------------------------------------------- | ---------------------------------------------- |
| `VM.Allocate`, `VM.Audit`                          | Create, read, destroy LXC containers           |
| `VM.Config.CPU/Memory/Disk/Network/Options/HWType` | Configure container resources                  |
| `Datastore.Allocate`                               | Register the `hdd-zfs` pool as Proxmox storage |
| `Datastore.AllocateSpace`, `Datastore.Audit`       | Allocate and read container disk volumes       |
| `Sys.Audit`                                        | Read node metadata for provider node discovery |

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

## ZFS pool + encrypted dataset

A ZFS mirror of the two 14.6 TB HDDs on the Proxmox host provides bulk storage and an encrypted dataset for per-host key
material. Each subdirectory under the encrypted dataset mounts exclusively into its own container.

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
1. **`null_resource.zfs_keys_unlock`** SSHes into the Proxmox node and runs `zfs load-key` + `zfs mount` with
   idempotency guards. On first apply the dataset is already unlocked + mounted (the operator just created it), so the
   guards skip both steps.

### Reboot-relock

After a Proxmox host reboot the encrypted dataset re-locks. Unlock it manually from the Tofu runner using the SOPS-held
password:

```fish
sops -d --extract '["homelab-zfs-passphrase"]' secrets/<runner>/secrets.yml | \
  ssh root@<proxmox-host> 'zfs load-key hdd-zfs/keys && zfs mount hdd-zfs/keys && zfs mount hdd-zfs/keys/cache && zfs mount hdd-zfs/keys/forge'
```

Mount the parent before its children — each child mounts under the parent's path. Add another
`&& zfs mount hdd-zfs/keys/<host>` clause when new per-host subdirectories come online.

## Bootstrap: template container → flake host

`apply` leaves a new container **created but stopped** (`started = false` in the resource). It still runs the generic
base template and must be converged onto its real flake host config once, by hand. The mechanism documented here is the
simplest one: SSH into the container and run `nixos-rebuild` from a local checkout of this repo. Remote pushes
(`nixos-rebuild --target-host`) and deploy-rs/colmena are possible future alternatives, out of scope for now.

The base template ([`../templates/lxc-base.nix`](../templates/lxc-base.nix)) boots with DHCP and runs `sshd` key-only
(root is `prohibit-password`, password auth off) — but it does **not** bake in an authorized key yet, so step 2 injects
yours via the Proxmox host. Baking the key into the template is the clean long-term home for this.

1. **Create and start the container.** `apply` creates it stopped; start it from the Proxmox host (CT id `107` =
   `edge`):

   ```fish
   scripts/tofu-sops.fish apply
   ssh root@<proxmox-host> pct start 107
   ```

1. **Inject your SSH key** (until the template bakes one in):

   ```fish
   scp ~/.ssh/id_ed25519.pub root@<proxmox-host>:/tmp/operator.pub
   ssh root@<proxmox-host> pct exec 107 -- mkdir -p -m 700 /root/.ssh
   ssh root@<proxmox-host> pct push 107 /tmp/operator.pub /root/.ssh/authorized_keys --perms 600
   ssh root@<proxmox-host> rm /tmp/operator.pub
   ```

1. **Find the DHCP lease** the template booted with:

   ```fish
   ssh root@<proxmox-host> pct exec 107 -- ip -4 -br addr show eth0
   ```

1. **Switch onto the flake host config.** SSH in, clone this repo, rebuild. The template carries `nix` (flakes enabled)
   and `git` for exactly this:

   ```fish
   ssh root@<dhcp-addr>
   git clone https://github.com/JHilmarch/nixos-config.git && cd nixos-config
   sudo nixos-rebuild switch --flake .#<host>
   ```

   From here the flake config owns the OS, including static addressing — the DHCP lease is replaced, so reconnect on the
   static IP. For `edge` the target flake host is the evolved jump host (tracked in #126, not yet in tree); it takes
   over static IP `192.168.2.107` / gateway `192.168.2.1`, exactly as
   [`../hosts/hl-jump/configuration.nix`](../hosts/hl-jump/configuration.nix) does today.

1. **Flip `started = true`.** Once converged, resolve the TODO in the container resource (`edge.tf`) so Tofu keeps the
   container running, re-apply, and commit the encrypted state as usual.

Verify:

```fish
# after tofu apply of edge:
ssh <container>
sudo nixos-rebuild switch --flake .#<host>
# host comes up with hostname + static IP 192.168.2.107
```

## Destroy / recreate a container from code

A container is disposable: it can be destroyed and rebuilt from this repo alone, because the resource definition is in
`tofu/` and its OS/services live in `hosts/<name>/`. Destroy one container without touching the others by targeting it:

```fish
# destroy just the edge container (leave others untouched)
scripts/tofu-sops.fish destroy -target proxmox_virtual_environment_container.edge

# recreate it, then follow the bootstrap above (start → inject key → nixos-rebuild switch)
scripts/tofu-sops.fish apply
```

`apply` re-creates the container from the same template and sizing, leaving it **stopped** (`started = false`); run the
[bootstrap](#bootstrap-template-container--flake-host) again to converge it back onto its flake host config. The result
is byte-for-byte the same working host — same hostname, static IP, and services — because every input is code.

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
