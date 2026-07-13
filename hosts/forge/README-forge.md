# forge — homelab git forge

A Proxmox LXC that hosts the homelab's self-hosted git forge: **Forgejo on a local PostgreSQL**, reached at
`https://forge.fileshare.se` through the edge reverse proxy, with a daily encrypted restic backup to the Synology NAS.

- **Host:** `nixos-forge` (flake attribute) / `forge` (hostname), CT 109, static IP `192.168.2.109`.
- **Container:** unprivileged + `nesting=true` (see
  [tofu/README.md "Nesting requirement"](../../tofu/README.md#nesting-requirement-systemd-256)).

## Workload

[`forgejo.nix`](configuration.nix) enables `services.forgejo` backed by a local PostgreSQL (the module provisions the
role + database because `database.type = "postgres"` and `createDatabase = true`). Forgejo binds the host LAN address
`192.168.2.109:3000` — edge terminates TLS for `forge.fileshare.se` and reverse-proxies to it over the LAN (RFC1918
allow-list), so no port is exposed off-LAN. Registration is disabled (single-operator forge — the admin account is
created out of band, below); session cookies are HTTPS-only; the small-instance `twoqueue` in-memory cache is used (no
external Redis); and the footer version is hidden.

`SECRET_KEY`, `INTERNAL_TOKEN`, and the DB password are read from the SOPS secrets (see below) rather than the module's
auto-generated files, so they are stable across a container recreate.

### Storage split (repos on HDD, DB on NVMe)

The git repositories and the Postgres data directory live on **different** pools, deliberately:

| Data                 | Path                     | Pool                                  | Why                                              |
| -------------------- | ------------------------ | ------------------------------------- | ------------------------------------------------ |
| Git repositories     | `/var/lib/forgejo-repos` | `hdd-zfs/data/forge` (encrypted, HDD) | bulk capacity; spinning disk is fine for a forge |
| Postgres data        | `/var/lib/postgresql`    | NVMe rootfs (`local-lvm`)             | latency-sensitive; keep the DB fast              |
| Forgejo state/config | `/var/lib/forgejo`       | NVMe rootfs (`local-lvm`)             | small, module default                            |

`repositoryRoot = "/var/lib/forgejo-repos"` points Forgejo's repo root at the `hdd-zfs/data/forge` bind mount declared
in [`tofu/forge.tf`](../../tofu/forge.tf). `hdd-zfs/data` is a separate encrypted dataset (its own encryptionroot,
sharing the keys passphrase) unlocked by `null_resource.zfs_keys_unlock` in [`tofu/storage.tf`](../../tofu/storage.tf);
like `/persist`, the repo data survives a container destroy/recreate because the dataset lives on the Proxmox host. See
[`tofu/README.md` "ZFS pool + encrypted dataset"](../../tofu/README.md#zfs-pool--encrypted-dataset) for the operator
`zfs create` step and the reboot-relock clause.

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

## Admin user (once per host lifetime)

Registration is disabled, so the first (admin) account is created out of band with the Forgejo CLI, run as the `forgejo`
user inside the container. The `forgejo` binary is **not** on the system `PATH` (the module runs it from the package
store path), so resolve it from the running service unit and pass the same work/custom dirs the service uses:

```fish
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@192.168.2.109 \
  'BIN=$(dirname $(systemctl show -p ExecStart --value forgejo | sed -n "s/.*path=\([^ ;]*\).*/\1/p")); \
   runuser -u forgejo -- env \
     FORGEJO_WORK_DIR=/var/lib/forgejo FORGEJO_CUSTOM=/var/lib/forgejo/custom \
     "$BIN/forgejo" admin user create \
       --admin --username <name> --email <you@example.com> --random-password \
       --config /var/lib/forgejo/custom/conf/app.ini'
```

`--random-password` prints a one-time password to log in with; change it in the UI afterwards. Additional users are
created the same way (drop `--admin`) or invited from within Forgejo.

## Backup and restore

[`restic.nix`](configuration.nix) runs `services.restic.backups.forge` daily at 05:30. Its `backupPrepareCommand` first
produces a consistent dump into `/var/lib/forgejo-backup` on the NVMe rootfs — a `forgejo dump` archive
(`forgejo-dump.tar`, repos + config + DB) plus a plain-SQL `pg_dump` (`forgejo-db.sql`) — then restic snapshots that
staging dir into an encrypted, deduplicated repository at `/var/lib/forgejo-backup-repo/restic`. Retention is
`--keep-daily 7 --keep-weekly 4 --keep-monthly 6`; the repo password is the `restic-forge-password` SOPS secret.

> **The repo lives on the NAS, bind-mounted in from the Proxmox host — restic never mounts NFS itself.** `forge` is an
> unprivileged LXC and cannot mount NFS from inside the guest (`mount.nfs: Operation not permitted`, exit 32, for any
> share or version — even ones a bare-metal host mounts fine). So pve mounts the Synology export and bind-mounts it into
> the container at `/var/lib/forgejo-backup-repo` (the third `mount_points` entry in
> [`tofu/forge.tf`](../../tofu/forge.tf)). The one-time operator setup — the pve `/etc/fstab` NFS entry (key the
> Synology export to the **Proxmox host's** LAN IP, not `forge.fileshare.se`, which resolves to edge) and attaching the
> bind mount — is in [`tofu/README.md` "NAS-backed backup mount"](../../tofu/README.md#nas-backed-backup-mount).

Run a backup on demand and list snapshots (restic reads its repo/password from the unit's environment):

```fish
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@192.168.2.109 \
  'systemctl start restic-backups-forge.service && journalctl -u restic-backups-forge -n 20 --no-pager'
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@192.168.2.109 \
  'restic -r /var/lib/forgejo-backup-repo/restic \
     --password-file /run/secrets/restic-forge-password snapshots'
```

**Restore** (into a scratch dir, then re-import — do a dry run at least once):

```fish
# 1. Restore the latest snapshot's dump files to a scratch dir.
restic -r /var/lib/forgejo-backup-repo/restic --password-file /run/secrets/restic-forge-password \
  restore latest --target /tmp/forge-restore

# 2. Recreate the Postgres DB from the SQL dump (stop Forgejo first).
systemctl stop forgejo
runuser -u postgres -- psql -d forgejo -f /tmp/forge-restore/var/lib/forgejo-backup/forgejo-db.sql

# 3. Restore repos/config from the forgejo dump per the Forgejo restore docs, then:
systemctl start forgejo
```

The `forgejo dump` archive is a standard zip/tar; unpack `repos/` back under `/var/lib/forgejo-repos` and the config
back under `/var/lib/forgejo` following the
[Forgejo backup-and-restore docs](https://forgejo.org/docs/latest/admin/backup-and-restore/). Because the repo root and
`/persist` live on the host's ZFS datasets, a container destroy/recreate alone already preserves repos + host key; the
restic restore is for NAS-side disaster recovery (lost container *and* pool).

## Files

| File                | Purpose                                                                            |
| ------------------- | ---------------------------------------------------------------------------------- |
| `configuration.nix` | Host config: networking, static IP, SSH host-key persistence, SOPS secret entries. |
| `forgejo.nix`       | Forgejo on local PostgreSQL; repo root on the `hdd-zfs` mount, DB + state on NVMe. |
| `restic.nix`        | Daily restic backup (Forgejo + Postgres dump) to the Synology NAS over NFS.        |
| `home.nix`          | Minimal Home Manager config (matches cache).                                       |
