{
  callPackage,
  project-manager,
}:
callPackage ./forgejo-base.nix {
  inherit project-manager;
  serviceName = "forgejo-project-manager";
  patSecret = "forgejo-pat";
}
