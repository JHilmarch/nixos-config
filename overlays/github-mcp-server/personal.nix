{
  self,
  super,
}: (import ./base.nix {
  inherit self super;
  serviceName = "github-personal-mcp";
  patSecret = "gh_personal_pat";
})
