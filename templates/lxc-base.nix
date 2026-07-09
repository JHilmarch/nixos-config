# Minimal standalone NixOS LXC base image for Proxmox. Build: nix build .#lxc-template
# See templates/README.md for the systemd v260 /run workaround and networking details.
{
  modulesPath,
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  nix.settings.sandbox = false;

  proxmoxLXC = {
    enable = true;
    manageNetwork = false;
    privileged = false;
  };

  services.fstrim.enable = false;
  documentation.man.enable = false;

  networking.useDHCP = lib.mkDefault true;

  systemd.network = {
    enable = true;
    networks."10-eth0" = {
      matchConfig.Name = "eth0";
      DHCP = "yes";
      networkConfig.IPv6AcceptRA = true;
    };
  };

  boot.postBootCommands = ''
    if [ -f /nix-path-registration ]; then
      ${lib.getExe' config.nix.package.out "nix-store"} --load-db < /nix-path-registration \
        && rm /nix-path-registration
    fi
    ${lib.getExe' config.nix.package.out "nix-env"} -p /nix/var/nix/profiles/system --set /run/current-system
  '';

  systemd.tmpfiles.rules = [
    "L+ /run/current-system - - - - /nix/var/nix/profiles/system"
    "L+ /run/booted-system - - - - /nix/var/nix/profiles/system"
  ];

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINZm7VWZl2HKD6ZPZWawFIunNLo3M6oJZSqe5lTQj64X tofu-remote-exec@p51"
  ];

  nix.settings.experimental-features = ["nix-command" "flakes"];

  environment.systemPackages = with pkgs; [
    git
    iproute2
    coreutils
    vim
  ];

  system.stateVersion = "26.05";
}
