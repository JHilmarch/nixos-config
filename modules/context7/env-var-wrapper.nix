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
