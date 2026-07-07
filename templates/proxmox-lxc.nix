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

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINZm7VWZl2HKD6ZPZWawFIunNLo3M6oJZSqe5lTQj64X tofu-remote-exec@p51"
  ];

  services.fstrim.enable = false;
  documentation.man.enable = false;
}
