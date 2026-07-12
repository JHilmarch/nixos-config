# Forgejo git forge on local PostgreSQL.
#
# Storage split (the restic backup config depends on these exact paths):
#   /var/lib/forgejo       — state dir on the NVMe rootfs (module default)
#   /var/lib/forgejo-repos — git repositories on the encrypted hdd-zfs/data/forge
#                            bind mount (tofu/forge.tf)
#   /var/lib/postgresql    — database on the NVMe rootfs (module default)
#
# The forgejo module auto-enables a local PostgreSQL with an ensured DB + user
# because database.type = "postgres" and createDatabase = true.
#
# edge terminates TLS for forge.fileshare.se and proxies to 192.168.2.109:3000
# over the LAN, so Forgejo binds the LAN address, not localhost.
{
  config,
  lib,
  pkgs,
  ...
}: {
  networking.firewall.allowedTCPPorts = [3000];

  services.forgejo = {
    enable = true;

    database = {
      type = "postgres";
      createDatabase = true;
      passwordFile = config.sops.secrets."forgejo-db-password".path;
    };

    # Sets settings.repository.ROOT plus forgejo:forgejo tmpfiles ownership.
    repositoryRoot = "/var/lib/forgejo-repos";

    settings = {
      server = {
        ROOT_URL = "https://forge.fileshare.se/";
        HTTP_ADDR = "192.168.2.109";
        HTTP_PORT = 3000;
      };

      session.COOKIE_SECURE = true;
      service.DISABLE_REGISTRATION = true;
      other.SHOW_FOOTER_VERSION = false;

      # Small-instance in-memory cache per the Forgejo admin recommendations.
      cache = {
        ADAPTER = "twoqueue";
        HOST = ''{"size":100,"recent_ratio":0.25,"ghost_ratio":0.5}'';
      };
    };

    # The module hard-sets both to files it generates on first boot, so
    # mkForce is required to swap in the SOPS-provisioned values.
    secrets.security = {
      SECRET_KEY = lib.mkForce config.sops.secrets."forgejo-secret-key".path;
      INTERNAL_TOKEN = lib.mkForce config.sops.secrets."forgejo-internal-token".path;
    };
  };
}
