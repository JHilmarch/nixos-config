{
  config,
  pkgs,
  username,
  ...
}: let
  context7-wrapped = pkgs.symlinkJoin {
    name = "context7-with-env";
    paths = [pkgs.local.context7-mcp];
    buildInputs = [pkgs.makeWrapper];
    postBuild = ''
      rm $out/bin/context7-mcp
      makeWrapper ${
        pkgs.local.context7-mcp
      }/bin/context7-mcp $out/bin/context7-with-env \
        --run '
      if [ -z "$CONTEXT7_TOKEN" ]; then
        CONTEXT7_TOKEN="$(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -Command "Write-Output ([System.Environment]::GetEnvironmentVariable('\"'\"'CONTEXT7_TOKEN'\"'\"', '\"'\"'User'\"'\"'))" 2>/dev/null || true)"
      fi
      if [ -z "$CONTEXT7_TOKEN" ]; then
        echo "Warning: CONTEXT7_TOKEN not set. Running in rate-limited mode." >&2
      fi
      export CONTEXT7_TOKEN
      '
    '';
  };
in {
  home-manager.users."${username}" = {
    home.packages = [context7-wrapped];
  };
}
