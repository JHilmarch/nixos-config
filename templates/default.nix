{
  common = import ./common.nix;
  desktop = import ./desktop.nix;
  server = import ./server.nix;
  proxmox-lxc = import ./proxmox-lxc.nix;
}
