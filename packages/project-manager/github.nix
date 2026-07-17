{callPackage}:
callPackage ../gh-cli/base.nix {
  serviceName = "github-project-manager";
  patSecret = "gh_personal_project_pat";
}
