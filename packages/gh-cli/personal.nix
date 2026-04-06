{callPackage}:
callPackage ./base.nix {
  serviceName = "gh-personal";
  patSecret = "gh_personal_pat";
}
