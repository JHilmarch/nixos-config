# Daily restic backup of Forgejo + Postgres state to the Synology NAS.
#
# The live Postgres data dir cannot be file-copied consistently, so
# backupPrepareCommand first produces a consistent `forgejo dump` archive
# (repos + DB + config) plus a plain-SQL pg_dump into the staging dir, and
# restic then snapshots that dir into an encrypted, deduplicated, auto-pruned
# repository on the NAS. Uncompressed dump formats are chosen deliberately:
# restic's own chunking/compression dedups them across days.
#
# forge is an UNPRIVILEGED LXC, which cannot mount NFS from inside the guest
# (the kernel denies the mount() syscall — Operation not permitted). So the
# Proxmox host mounts the NAS and bind-mounts it into the container at
# /var/lib/forgejo-backup-repo (a third tofu mount_points entry). restic sees
# a plain local directory; the NFS lives entirely on the privileged host. See
# tofu/README.md "NAS-backed backup mount" and hosts/forge/README-forge.md.
{
  config,
  lib,
  pkgs,
  ...
}: let
  stagingDir = "/var/lib/forgejo-backup";
  repoDir = "/var/lib/forgejo-backup-repo";
in {
  services.restic.backups.forge = {
    initialize = true;
    repository = "${repoDir}/restic";
    passwordFile = config.sops.secrets."restic-forge-password".path;
    paths = [stagingDir];

    backupPrepareCommand = let
      forgejo = config.services.forgejo;
      # services.postgresql.package only has a value once T2 enables postgres.
      postgresqlPackage =
        if config.services.postgresql.enable
        then config.services.postgresql.package
        else pkgs.postgresql;
    in ''
      #!${pkgs.runtimeShell}
      set -euo pipefail

      ${pkgs.coreutils}/bin/rm -rf ${stagingDir}
      ${pkgs.coreutils}/bin/install -d -m 0750 -o ${forgejo.user} -g ${forgejo.group} ${stagingDir}

      ${pkgs.util-linux}/bin/runuser -u ${forgejo.user} -g ${forgejo.group} -- \
        ${pkgs.coreutils}/bin/env \
        USER=${forgejo.user} \
        HOME=${forgejo.stateDir} \
        FORGEJO_WORK_DIR=${forgejo.stateDir} \
        FORGEJO_CUSTOM=${forgejo.customDir} \
        ${lib.getExe forgejo.package} dump --type tar --file ${stagingDir}/forgejo-dump.tar

      ${pkgs.util-linux}/bin/runuser -u postgres -- \
        ${postgresqlPackage}/bin/pg_dump --format=plain ${forgejo.database.name} \
        > ${stagingDir}/forgejo-db.sql
    '';

    timerConfig = {
      OnCalendar = "05:30";
      Persistent = true;
    };

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
  };

  # The repo lives on the pve-mounted NAS bind mount; fail loudly if it is not
  # present rather than silently backing up into the container rootfs.
  systemd.services.restic-backups-forge.serviceConfig.ExecStartPre = lib.mkBefore [
    "${pkgs.coreutils}/bin/test -d ${repoDir}"
  ];
}
