#!/usr/bin/env fish
# @fish-lsp-disable 4004
# ssh-signing-bootstrap.fish — One-shot SSH commit-signing key bootstrap
#
# WHAT: Fetches the ed25519 commit-signing key from 1Password and writes it
#       to ~/.ssh/signing_keys/id_ed25519_signing so git can sign commits
#       using ssh-keygen against a file, instead of the live 1Password SSH
#       agent (op-ssh-sign). The agent socket (~/.1password/agent.sock) is
#       unreachable from OpenCode / agent jails, which broke every signed
#       commit made by an agent.
#
# WHEN: Run ONCE on the host (orion / p51) after `home-manager switch` /
#       `nixos-rebuild switch` has applied the file-based signing config in
#       home-modules/git/ssh.nix. Re-run with --force after rotating the key.
#
# WHERE: Run on the HOST, never from inside a jail/sandbox (op is not on the
#         jail PATH and the script touches ~/.ssh/signing_keys/).
#
# Usage:
#   fish scripts/ssh-signing-bootstrap.fish --item "GitHub Signing Key"
#   fish scripts/ssh-signing-bootstrap.fish --item "GitHub Signing Key" --field "private key"
#   fish scripts/ssh-signing-bootstrap.fish --item "GitHub Signing Key" --force
#   fish scripts/ssh-signing-bootstrap.fish --help
#
# Prerequisites:
#   - _1password-cli installed (provides `op`)
#   - jq installed (used to parse 1Password JSON output)
#   - Authenticated: `op signin`
#   - The signing key stored as an SSH Key item in 1Password, with its public
#     half matching the fingerprint configured in home-modules/git/ssh.nix
#     (ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbXmkI4z9yvrdcHtGxdAx41THZJsps8irUTcyEzMxo).
#
# After running, verify a signed commit succeeds inside the jail:
#   git commit --allow-empty -m "test: verify file-based SSH signing"
#   git log --show-signature -1

# --- logging (self-contained; mirrors tools/common/log.fish without JSON mode) ---
function log_step -d "Print step indicator"
    set_color blue
    printf "  -> %s\n" "$argv" >&2
    set_color normal
end

function log_success -d "Print success message"
    set_color green
    printf "  ✓ %s\n" "$argv" >&2
    set_color normal
end

function log_info -d "Print info message"
    set_color green
    printf "INFO: %s\n" "$argv" >&2
    set_color normal
end

function log_error -d "Print error message"
    set_color red
    printf "ERROR: %s\n" "$argv" >&2
    set_color normal
end

function die -d "Print error and exit"
    set_color red
    printf "Error: %s\n" "$argv[1]" >&2
    set_color normal
    exit 1
end

# --- constants ---
set -l KEY_PATH ~/.ssh/signing_keys/id_ed25519_signing
set -l DEFAULT_FIELD "private key"
set -l EXPECTED_PUBKEY "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbXmkI4z9yvrdcHtGxdAx41THZJsps8irUTcyEzMxo"
set -l KEY_DIR (dirname $KEY_PATH)

# --- argument parsing ---
set -l item
set -l field $DEFAULT_FIELD
set -l force false

argparse --name=ssh-signing-bootstrap h/help 'item=' 'field=' f/force -- $argv
or die "Invalid arguments. Run with --help for usage."

if set -q _flag_help
    echo "ssh-signing-bootstrap.fish — bootstrap file-based SSH commit signing"
    echo ""
    echo "Usage:"
    echo "  fish scripts/ssh-signing-bootstrap.fish --item <1Password-item> [options]"
    echo ""
    echo "Options:"
    echo "  --item <name>   1Password item holding the ed25519 signing key (required)"
    echo "  --field <name>  Field label or ID for the private key (default: \"$DEFAULT_FIELD\")"
    echo "  --force         Overwrite an existing key file at $KEY_PATH"
    echo "  -h, --help      Show this help"
    exit 0
end

if not set -q _flag_item; or test -z "$_flag_item"
    die "Missing required --item <1Password-item>. Run with --help for usage."
end
set item $_flag_item
set -q _flag_field; and set field $_flag_field
if set -q _flag_force
    set force true
end

# --- preflight checks ---
log_step "Preflight checks"

if not command -q op
    die "'op' (1Password CLI) not found on PATH. Install _1password-cli on the host."
end

if not command -q jq
    die "'jq' not found on PATH. Install jq on the host."
end

if not op user >/dev/null 2>&1
    die "Not signed in to 1Password. Run 'op signin' first."
end

if test -e $KEY_PATH; and test "$force" = false
    die "Key file already exists: $KEY_PATH. Re-run with --force to overwrite."
end

# --- fetch private key from 1Password ---
# Parse via JSON + jq instead of --fields, because op wraps SSHKEY-type
# field values in literal double quotes that corrupt the key file.
log_step "Fetching private key from 1Password item: $item (field: $field)"
set -l private_key (op item get "$item" --format json 2>/dev/null | jq -r --arg f "$field" '.fields[] | select(.id == $f or .label == $f) | .value' | string collect)
if test $status -ne 0; or test -z "$private_key"
    die "Failed to retrieve key from 1Password. Check --item and --field values, and that the item is an SSH Key type."
end

# --- write key file ---
log_step "Writing key to $KEY_PATH"
mkdir -p $KEY_DIR
or die "Failed to create directory: $KEY_DIR"
chmod 700 $KEY_DIR
or die "Failed to chmod 700 on $KEY_DIR"

printf '%s\n' $private_key >$KEY_PATH
or die "Failed to write key file: $KEY_PATH"
chmod 600 $KEY_PATH
or die "Failed to chmod 600 on $KEY_PATH"

# --- verify: file is a valid SSH key matching the configured public key ---
log_step "Verifying key validity and fingerprint match"
if not command -q ssh-keygen
    die "ssh-keygen not found on PATH. Install openssh on the host."
end

set -l derived_pubkey (ssh-keygen -y -f $KEY_PATH 2>/dev/null | string collect)
if test $status -ne 0; or test -z "$derived_pubkey"
    die "Key file at $KEY_PATH is not a valid SSH private key. The 1Password field may not contain key material."
end

# ssh-keygen -y appends a comment (e.g. user@email); compare only type + base64
set -l derived_parts (string split ' ' -- $derived_pubkey)
set -l derived_key "$derived_parts[1] $derived_parts[2]"

if test "$derived_key" != "$EXPECTED_PUBKEY"
    log_error "Derived public key does not match the configured signing key."
    log_error "  Expected: $EXPECTED_PUBKEY"
    log_error "  Got:      $derived_key"
    die "Key mismatch. Ensure the 1Password item holds the correct signing key."
end

# --- verify permissions ---
if test (stat -c '%a' $KEY_PATH) != 600
    die "Permissions on $KEY_PATH are not 600 — refusing to proceed."
end

log_success "Signing key written and verified: $KEY_PATH (600)"
log_info "Key matches the public key configured in home-modules/git/ssh.nix"
log_info ""
log_info "Next steps:"
log_info "  1. Apply the host config:"
log_info "       sudo nixos-rebuild switch --flake .#nixos-orion"
log_info "  2. Test a signed commit inside the OpenCode jail (no 1Password agent needed):"
log_info "       git commit --allow-empty -m \"test: verify file-based SSH signing\""
log_info "  3. Confirm the signature:"
log_info "       git log --show-signature -1"
