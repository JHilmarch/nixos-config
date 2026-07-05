{config, ...}: {
  services.acmeWildcard.enable = true;

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
}
