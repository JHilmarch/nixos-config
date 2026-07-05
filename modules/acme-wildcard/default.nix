# Cloudflare DNS-01 wildcard certificate for *.fileshare.se.
#
# Encapsulates the security.acme cert, the cloudflare-token SOPS secret, the
# cloudflare.env template, and the nginx → acme group membership. Hosts flip
# services.acmeWildcard.enable and get the correct, consistent setup with the
# --dns.propagation-wait fix that reliably issues the cert.
#
# The fileshare.se zone uses a _acme-challenge CNAME, and Cloudflare's
# authoritative nameservers refuse lego's propagation checks (REFUSED / 403 no
# TXT record). Passing --dns.propagation-wait 90s makes lego wait a fixed
# interval and lets Let's Encrypt validate the record itself, rather than
# polling. See hosts/cache/README-cache.md for the full background.
{
  config,
  lib,
  ...
}: let
  cfg = config.services.acmeWildcard;
  domain = "fileshare.se";
in {
  options.services.acmeWildcard = {
    enable = lib.mkEnableOption "Cloudflare DNS-01 wildcard certificate for *.${domain} (shared module carrying the --dns.propagation-wait fix)";
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."cloudflare-token" = {};

    sops.templates."cloudflare.env".content = ''
      CF_DNS_API_TOKEN=${config.sops.placeholder."cloudflare-token"}
    '';

    security.acme = {
      acceptTerms = true;
      defaults.email = "admin@${domain}";
      certs."${domain}" = {
        inherit domain;
        extraDomainNames = ["*.${domain}"];
        email = "cloudflare.wilder179@dralias.com";
        dnsProvider = "cloudflare";
        # Fixed wait instead of a propagation poll — Cloudflare's authoritative
        # NS refuses lego's checks; this lets LE validate the record directly.
        extraLegoFlags = ["--dns.propagation-wait" "90s"];
        environmentFile = config.sops.templates."cloudflare.env".path;
      };
    };

    # nginx reads the issued certs from the acme group.
    users.users.nginx.extraGroups = ["acme"];
  };
}
