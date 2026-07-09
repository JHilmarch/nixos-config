# nginx reverse-proxy ingress for *.fileshare.se.
#
# Enables nginx with the recommended TLS/proxy settings and opens 80/443, and
# expands services.nginxIngress.virtualHosts into *.fileshare.se vhosts wired to
# the wildcard cert from services.acmeWildcard (forceSSL + useACMEHost +
# proxyPass). A backend is one virtualHosts entry keyed by FQDN; anything beyond
# a single "/" proxy goes directly under services.nginx.virtualHosts.
#
# Each vhost is LAN-only by default (external = false): the "/" location gets an
# RFC1918 allow-list + `deny all`, so only private-range clients reach the
# backend even though 80/443 are open on the firewall (ACME HTTP needs them).
# Set external = true to drop the allow-list and expose the vhost to WAN — the
# single explicit change that opts a backend into the external tier (#126).
{
  config,
  lib,
  ...
}: let
  cfg = config.services.nginxIngress;
  domain = "fileshare.se";
  # RFC1918 private ranges — the LAN source-range allow-list for internal vhosts.
  lanRanges = [
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
  ];
  lanAllowDeny =
    (lib.concatMapStrings (range: "allow ${range};\n") lanRanges)
    + "deny all;";
  vhostType = lib.types.submodule {
    options = {
      proxyPass = lib.mkOption {
        type = lib.types.str;
        description = "Upstream to proxy '/' to (e.g. http://127.0.0.1:5000).";
      };
      external = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether this vhost is reachable from WAN. Default (false) restricts the
          "/" location to RFC1918 LAN source ranges (`allow` ${builtins.concatStringsSep ", " lanRanges} + `deny all`),
          so only LAN clients reach the backend. Set true to remove the
          allow-list and expose the vhost publicly (still requires a WAN
          port-forward at the router). Opting a backend into the external tier is
          this single explicit change.
        '';
      };
    };
  };
in {
  options.services.nginxIngress = {
    enable = lib.mkEnableOption "shared nginx reverse-proxy ingress for *.${domain} (recommended* settings, 80/443 firewall, and a .${domain} vhost helper — pairs with services.acmeWildcard)";

    virtualHosts = lib.mkOption {
      type = lib.types.attrsOf vhostType;
      default = {};
      description = ''
        Reverse-proxy vhosts keyed by FQDN (e.g. `cache.${domain}`). Each entry
        is expanded to `forceSSL = true`, `useACMEHost = "${domain}"` (the
        *.${domain} wildcard cert issued by services.acmeWildcard), and
        `locations."/".proxyPass` set to the given upstream. Adding a backend
        is one entry here — no hand-rolled nginx. Each vhost is LAN-only unless
        its `external` flag is set (see the option below).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;

      virtualHosts =
        lib.mapAttrs (_name: vhost: {
          forceSSL = true;
          useACMEHost = domain;
          locations."/" = {
            proxyPass = vhost.proxyPass;
            # LAN-only vhosts get an RFC1918 allow-list + deny-all; external
            # vhosts drop it and are reachable from any source.
            extraConfig = lib.optionalString (!vhost.external) lanAllowDeny;
          };
        })
        cfg.virtualHosts;
    };

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [
        80
        443
      ];
    };
  };
}
