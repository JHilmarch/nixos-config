# Minimal NixOS LXC base image for the homelab.
#
# This is the template that OpenTofu-provisioned Proxmox containers boot from.
# It is intentionally self-contained: it does NOT import the host-specific
# `server.nix`/`common.nix` chain (which needs `self`, `username`, `users/`,
# SOPS, etc.), so it can be built standalone from a clean checkout:
#
#   nix build .#lxc-template
#
# The image only needs to do four things:
#   1. boot as a privileged Proxmox LXC container,
#   2. come up on the network (DHCP by default; the per-host flake config takes
#      over static addressing, as `hl-jump` does today),
#   3. accept SSH so the operator can reach it, and
#   4. carry `nix` + `git` so `nixos-rebuild` can switch it onto its real flake
#      host config, after which this base is fully superseded.
#
# Everything beyond that (services, users, secrets, static IPs) is owned by the
# per-host NixOS configuration under `hosts/<name>/`.
#
# systemd stage-1 is disabled: on 26.05 it moves activation into an initrd,
# which LXC has none of, so the system never activates (nixpkgs#529888).
{
  modulesPath,
  pkgs,
  lib,
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

  # Required for LXC activation — see the header (nixpkgs#529888).
  boot.initrd.systemd.enable = lib.mkForce false;

  networking.useDHCP = lib.mkDefault true;

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  nix.settings.experimental-features = ["nix-command" "flakes"];

  environment.systemPackages = with pkgs; [
    git
    coreutils
    vim
  ];

  system.stateVersion = "26.05";
}
