# forge — homelab git forge

A Proxmox LXC that will host the homelab's self-hosted git forge (Forgejo + Postgres). Base host with SSH host-key
persistence and SOPS secrets in place; the Forgejo + Postgres workload lands in T2.

- **Host:** `nixos-forge` (flake attribute) / `forge` (hostname), CT 109, static IP `192.168.2.109`.
- **Container:** unprivileged + `nesting=true` (see
  [tofu/README.md "Nesting requirement"](../../tofu/README.md#nesting-requirement-systemd-256)).

## Current state

The host imports [`templates/proxmox-lxc.nix`](../../templates/proxmox-lxc.nix) and declares only its unique delta:
hostname, static IP (`192.168.2.109/24`), `stateVersion`, SSH host-key persistence, and its SOPS secret entries. The
template provides nix.gc, resolved/DNS, LAN nameservers + gateway, openssh `openFirewall`, unprivileged + nesting, and
SOPS wiring.

No Forgejo or Postgres workload is configured yet — that arrives in T2.

## Secrets and key persistence

`services.sshHostKeyPersistence.enable` redirects the SSH host key (and the sops-nix age identity derived from it) to
the `/persist` bind mount, so the committed `.sops.yaml` recipient survives a container destroy/recreate with no
`sops updatekeys`. `/persist` is `tofu/forge.tf`'s `mount_points` entry mapping `/hdd-zfs/keys/forge` — the per-host
subdirectory of the encrypted ZFS dataset — into the container. See
[`README-cache.md` "SSH host key persistence"](../cache/README-cache.md#ssh-host-key-persistence) for the shared
mechanism and the first-ever-bootstrap flow that derives the age recipient.

The `sops.secrets` entries (`forgejo-secret-key`, `forgejo-internal-token`, `forgejo-db-password`,
`restic-forge-password`) expose the decrypted paths consumed by the Forgejo service and the restic backup. Their owner
and group are left at the default until the Forgejo service (and its user) exist; the workload attaches ownership when
it wires the secrets. The encrypted `secrets/forge/secrets.yml` and the `&forge` recipient in `.sops.yaml` are the
operator's YubiKey-gated bootstrap step.

## Edge ingress

Edge terminates TLS for `forge.fileshare.se` and reverse-proxies to `http://192.168.2.109:3000` (Forgejo's default HTTP
port) — LAN-only by default (RFC1918 allow-list). See [`hosts/edge/configuration.nix`](../edge/configuration.nix).

## Provisioning, bootstrap, and destroy/recreate

The generic LXC lifecycle (tofu apply, bootstrap onto flake config, destroy/recreate from code) is documented in
[`tofu/README.md`](../../tofu/README.md). The forge-specific values:

| What         | Value           |
| ------------ | --------------- |
| CT id        | 109             |
| Flake target | `.#nixos-forge` |
| Static IP    | `192.168.2.109` |
| Gateway      | `192.168.2.1`   |

### First-ever bootstrap (once per host lifetime)

The `&forge` age recipient is derived from the persisted SSH host key, which only exists **after** the first switch —
but that first switch cannot evaluate while `sops.secrets` references a `secrets/forge/secrets.yml` that does not exist
yet. Break the chicken-and-egg by bootstrapping without secrets first, then adding them:

1. **Comment out the `sops.secrets` block** in [`configuration.nix`](configuration.nix) (the `sopsFile` assertion fails
   at eval time until the encrypted file exists, which blocks the switch that generates the host key).

1. **Switch onto the DHCP lease, not the static IP.** The base template boots on DHCP (see
   [`tofu/README.md` "Bootstrap"](../../tofu/README.md#bootstrap-template-container--flake-host)); the static
   `192.168.2.109` only comes up *after* this switch. Find the lease via Proxmox, then push the closure. Run from a repo
   checkout on the tofu runner (p51). Under `sudo`, `~` resolves to `/root`, so pass the **absolute** key path:

   ```fish
   ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@<proxmox-host> \
     'pct exec 109 -- /run/current-system/sw/bin/ip -4 -br addr show eth0'   # → the DHCP lease
   sudo env NIX_SSHOPTS="-o IdentitiesOnly=yes -i /home/jonatan/.ssh/id_ed25519_tofu -o StrictHostKeyChecking=accept-new" \
     nixos-rebuild switch --flake .#nixos-forge --target-host root@<dhcp-lease>
   ```

   The SSH connection **drops mid-activation** when networking flips DHCP → static — expected, not a hang. Reboot to
   finish, then confirm the static IP took:

   ```fish
   ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@<proxmox-host> 'pct reboot 109'
   ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@<proxmox-host> \
     'pct exec 109 -- /run/current-system/sw/bin/ip -4 -br addr show eth0'   # → 192.168.2.109/24
   ```

1. **Derive the `&forge` recipient** from the now-persisted key. `pct exec` needs the full NixOS binary path, and
   `ssh-to-age` runs on p51 (it is in p51's packages):

   ```fish
   ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@<proxmox-host> \
     'pct exec 109 -- /run/current-system/sw/bin/ssh-keygen -y -f /persist/ssh/ssh_host_ed25519_key' | ssh-to-age
   # → age1…   (add as the &forge recipient + a secrets/forge/ creation rule in .sops.yaml)
   ```

1. **Encrypt the secrets** (YubiKey), then re-enable the `sops.secrets` block and re-switch on the static IP:

   ```fish
   sops secrets/forge/secrets.yml   # forgejo-secret-key / -internal-token / -db-password / restic-forge-password
   sudo env NIX_SSHOPTS="-o IdentitiesOnly=yes -i /home/jonatan/.ssh/id_ed25519_tofu -o StrictHostKeyChecking=accept-new" \
     nixos-rebuild switch --flake .#nixos-forge --target-host root@192.168.2.109
   ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@<proxmox-host> \
     'pct exec 109 -- /run/current-system/sw/bin/ls -1 /run/secrets/'   # → the 4 decrypted secrets
   ```

Every later `tofu destroy`/`apply` skips this — the persisted key is remounted and the committed recipient stays valid.
Generate the Forgejo secret values with `nix run nixpkgs#forgejo -- generate secret SECRET_KEY` (and `INTERNAL_TOKEN`);
the DB and restic passwords are any `openssl rand -base64 32`.

## Files

| File                | Purpose                                                                            |
| ------------------- | ---------------------------------------------------------------------------------- |
| `configuration.nix` | Host config: networking, static IP, SSH host-key persistence, SOPS secret entries. |
| `home.nix`          | Minimal Home Manager config (matches cache).                                       |
