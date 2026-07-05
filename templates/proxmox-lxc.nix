{
  modulesPath,
  lib,
  ...
}: {
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ./server.nix
  ];

  nix.settings.sandbox = false;

  proxmoxLXC = {
    manageNetwork = true;
    privileged = lib.mkDefault true;
  };

  services.fstrim.enable = false; # Let Proxmox host handle fstrim
  documentation.man.enable = false;
}
