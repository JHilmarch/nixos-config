#!/usr/bin/env fish

# tofu-sops.fish — run OpenTofu against the homelab Proxmox with SOPS-sourced
# credentials and SOPS-encrypted state.
#
# It does three things around every `tofu` invocation:
#   1. Decrypts the Proxmox API token from SOPS and exports it into the env
#      (PROXMOX_VE_ENDPOINT / PROXMOX_VE_API_TOKEN) so nothing hits the tree.
#   2. Decrypts the committed state (terraform.tfstate.enc) to a plaintext
#      terraform.tfstate before running.
#   3. Re-encrypts the resulting state back to terraform.tfstate.enc and shreds
#      the plaintext afterwards, so only the encrypted state is ever committed.
#
# Usage (run from anywhere; paths are resolved relative to this script):
#   scripts/tofu-sops.fish init
#   scripts/tofu-sops.fish plan
#   scripts/tofu-sops.fish apply
#   scripts/tofu-sops.fish <any-tofu-subcommand-and-flags...>
#
# Requirements: sops, age (+ the repo's age/YubiKey setup), tofu, fish.
#
# Secret layout (add interactively with `sops secrets/<host>/secrets.yml`):
#   proxmox_ve_endpoint:  "https://192.168.2.10:8006/"
#   proxmox_ve_api_token: "root@pam!tofu=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

set -l script_dir (dirname (status --current-filename))
set -l repo_root (realpath "$script_dir/..")
set -l tofu_dir "$repo_root/tofu"
set -l secret_file "$repo_root/secrets/p51/secrets.yml"
set -l state_enc "$tofu_dir/terraform.tfstate.enc"
set -l state_plain "$tofu_dir/terraform.tfstate"

if test (count $argv) -eq 0
    echo "Usage: tofu-sops.fish <tofu-subcommand> [args...]" >&2
    echo "Examples: tofu-sops.fish init | plan | apply" >&2
    exit 1
end

# --- Preflight ------------------------------------------------------------

for bin in sops tofu
    if not command -q $bin
        echo "Error: required command '$bin' not found on PATH" >&2
        echo "       enter the devshell (nix develop) or install it first" >&2
        exit 1
    end
end

if not test -f "$secret_file"
    echo "Error: Proxmox secret not found: $secret_file" >&2
    echo "" >&2
    echo "Create it interactively (requires your YubiKey/age key):" >&2
    echo "    sops $secret_file" >&2
    echo "" >&2
    echo "with keys:" >&2
    echo "    proxmox_ve_endpoint:  \"https://<proxmox-host>:8006/\"" >&2
    echo "    proxmox_ve_api_token: \"root@pam!tofu=<uuid>\"" >&2
    exit 1
end

# --- Credentials ----------------------------------------------------------

# Decrypt individual values straight into the environment; never touch disk.
set -l endpoint (sops --decrypt --extract '["proxmox_ve_endpoint"]' "$secret_file")
if test $status -ne 0
    echo "Error: failed to decrypt proxmox_ve_endpoint from $secret_file" >&2
    exit 1
end

set -l api_token (sops --decrypt --extract '["proxmox_ve_api_token"]' "$secret_file")
if test $status -ne 0
    echo "Error: failed to decrypt proxmox_ve_api_token from $secret_file" >&2
    exit 1
end

set -gx PROXMOX_VE_ENDPOINT "$endpoint"
set -gx PROXMOX_VE_API_TOKEN "$api_token"

# Derive the Proxmox SSH host from the API endpoint so there's one source of
# truth for the host address. Used by null_resource remote-exec in storage.tf.
set -l ssh_host (string replace -r '^https?://' '' -- "$endpoint" | string replace -r '[:/].*$' '' --)
if test -n "$ssh_host"
    set -gx TF_VAR_proxmox_ssh_host "$ssh_host"
else
    echo "Warning: could not derive proxmox_ssh_host from endpoint '$endpoint'" >&2
end

# --- ZFS dataset passphrase (optional, used by tofu/storage.tf) -------------
#
# Only exported when the key is present, so early provisioning runs (before
# the encrypted dataset exists) still apply without it.

set -l zfs_passphrase (sops --decrypt --extract '["homelab-zfs-passphrase"]' "$secret_file" 2>/dev/null)
if test $status -eq 0
    set -gx TF_VAR_homelab_zfs_passphrase "$zfs_passphrase"
else
    echo "Note: 'homelab-zfs-passphrase' not found in $secret_file — skipping export." >&2
    echo "      Required only once the hdd-zfs/keys dataset exists (see issue #166)." >&2
end

# --- State: decrypt-on-read ----------------------------------------------

function __cleanup_plaintext_state --inherit-variable state_plain
    if test -f "$state_plain"
        # Best-effort shred, then remove. Plaintext state must not linger.
        command shred -u "$state_plain" 2>/dev/null; or rm -f "$state_plain"
    end
end

if test -f "$state_enc"
    if not sops --decrypt "$state_enc" >"$state_plain"
        echo "Error: failed to decrypt $state_enc" >&2
        __cleanup_plaintext_state
        exit 1
    end
end

# --- Run tofu -------------------------------------------------------------

pushd "$tofu_dir"
tofu $argv
set -l tofu_status $status
popd

# --- State: encrypt-on-write ---------------------------------------------

if test -f "$state_plain"
    if sops --encrypt "$state_plain" >"$state_enc"
        __cleanup_plaintext_state
    else
        echo "Error: failed to re-encrypt state to $state_enc" >&2
        echo "       plaintext state left at $state_plain — encrypt it before committing!" >&2
        exit 1
    end
end

exit $tofu_status
