{callPackage}:
callPackage ./base.nix {
  serviceName = "gh-personal-project-manager";
  patSecret = "gh_personal_project_pat";
}
