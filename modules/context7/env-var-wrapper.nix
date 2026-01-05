{
  config,
  pkgs,
  username,
  ...
}: let
  context7-with-env = pkgs.writeShellApplication {
    name = "context7-with-env";
    runtimeInputs = [pkgs.context7];
    text = ''
      # If not set in Linux, try Windows environment variable (for WSL)
      if [ -z "$CONTEXT7_TOKEN" ]; then
        CONTEXT7_TOKEN=$(powershell.exe -NoProfile -Command "[System.Environment]::GetEnvironmentVariable('CONTEXT7_TOKEN', 'User')" 2>/dev/null || true)
      fi

      if [ -z "$CONTEXT7_TOKEN" ]; then
        echo "Warning: CONTEXT7_TOKEN environment variable is not set." >&2
        echo "Context7 will work with rate limits. Set the token for unlimited access." >&2
      fi

      if [ -n "$CONTEXT7_TOKEN" ]; then
        exec ${pkgs.context7}/bin/context7 --api-key "$CONTEXT7_TOKEN" "$@"
      else
        exec ${pkgs.context7}/bin/context7 "$@"
      fi
    '';
  };
in {
  home-manager.users."${username}" = {
    home.packages = [context7-with-env];
  };
}
