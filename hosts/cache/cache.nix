{config, ...}: {
  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;

    virtualHosts."cache.fileshare.se" = {
      forceSSL = true;
      useACMEHost = "fileshare.se";
      locations."/" = {
        proxyPass = "http://127.0.0.1:5000";
      };
    };
  };
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80
      443
    ];
  };

  sops.secrets."cloudflare-token" = {};
  sops.templates."cloudflare.env".content = ''
    CF_DNS_API_TOKEN=${config.sops.placeholder."cloudflare-token"}
  '';
  security.acme = {
    acceptTerms = true;
    defaults.email = "admin@fileshare.se";
    certs."fileshare.se" = {
      domain = "fileshare.se";
      extraDomainNames = ["*.fileshare.se"];
      email = "cloudflare.wilder179@dralias.com";
      dnsProvider = "cloudflare";
      dnsResolver = "1.1.1.1:53";
      dnsPropagationCheck = true;
      environmentFile = config.sops.templates."cloudflare.env".path;
    };
  };
  users.users.nginx.extraGroups = ["acme"];
}
