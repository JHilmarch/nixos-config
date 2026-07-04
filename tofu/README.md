# Homelab provisioning (OpenTofu)

Declarative provisioning for the homelab's Proxmox LXC containers. Tofu **creates and sizes** containers on the Proxmox
host; each container's NixOS config (under `hosts/<name>/`) owns its OS, services, and static IP.

## Layout

| File          | Purpose                                                                    |
| ------------- | -------------------------------------------------------------------------- |
| `versions.tf` | Pins OpenTofu (`>= 1.6`) and the `bpg/proxmox` provider (`~> 0.111`).      |
| `provider.tf` | Configures the `proxmox` provider; reads credentials from the environment. |
| `.gitignore`  | Keeps plaintext state and the provider cache out of git.                   |

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
