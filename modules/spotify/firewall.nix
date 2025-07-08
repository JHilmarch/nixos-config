{ config, lib, ... }:

let
  ports = {
    spotify-localDiscovery-casting = 5353;
    spotify-localDiscovery-mobileSync = 57621;
  };
in
{
  options = {
    services.spotifyFirewall.enable = lib.mkEnableOption "Open firewall ports for Spotify";
  };

  config = lib.mkIf config.services.spotifyFirewall.enable {
    assertions = [
      {
        assertion = config.networking.firewall.enable;
        message = "Spotify firewall module requires networking.firewall.enable = true";
      }
    ];

    networking.firewall.allowedTCPPorts = [
      ports.spotify-localDiscovery-casting
      ports.spotify-localDiscovery-mobileSync
    ];

    networking.firewall.allowedUDPPorts = [ ports.spotify-localDiscovery-mobileSync ];
  };
}
