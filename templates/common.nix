{
  pkgs,
  self,
  ...
}: {
  imports = ["${self}/modules/defaults.nix"];

  programs = {
    fish.enable = true;
    nix-ld.enable = true;
  };

  security.sudo.wheelNeedsPassword = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    coreutils # A collection of basic file, shell, and text manipulation utilities. ls, cat, rm, cp...
    git # Distributed version control system
    vim # Most popular clone of the VI editor
  ];
}
