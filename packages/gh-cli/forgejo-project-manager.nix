{
  callPackage,
  gh-project-manager,
}:
callPackage ./forgejo-base.nix {
  inherit gh-project-manager;
  serviceName = "forgejo-project-manager";
  patSecret = "forgejo-pat";
}
