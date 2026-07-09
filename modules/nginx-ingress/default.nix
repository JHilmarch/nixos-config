# nginx reverse-proxy ingress for *.fileshare.se.
#
# Enables nginx with the recommended TLS/proxy settings and opens 80/443, and
# expands services.nginxIngress.virtualHosts into *.fileshare.se vhosts wired to
# the wildcard cert from services.acmeWildcard (forceSSL + useACMEHost +
# proxyPass). A backend is one virtualHosts entry keyed by FQDN; anything beyond
# a single "/" proxy goes directly under services.nginx.virtualHosts.
{
  config,
  lib,
  ...
}: let
  cfg = config.services.nginxIngress;
  domain = "fileshare.se";
  vhostType = lib.types.submodule {
    options.proxyPass = lib.mkOption {
      type = lib.types.str;
      description = "Upstream to proxy '/' to (e.g. http://127.0.0.1:5000).";
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
        is one entry here — no hand-rolled nginx.
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
          locations."/".proxyPass = vhost.proxyPass;
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
