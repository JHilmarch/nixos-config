{
  self,
  super,
}: (import ./base.nix {
  inherit self super;
  serviceName = "github-work-mcp";
  patSecret = "gh_work_pat";
})
