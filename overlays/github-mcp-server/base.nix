{
  serviceName,
  patSecret,
  self,
  super,
}:
super.writeShellApplication {
  name = serviceName;

  runtimeEnv = {
    PATH = super.lib.strings.makeBinPath [
      super.findutils
      super.github-mcp-server
    ];
  };

  text = ''
    SECRET_FILE="''${XDG_RUNTIME_DIR}/secrets/${patSecret}"
    if [ ! -f "$SECRET_FILE" ]; then
      SECRET_FILE="/run/secrets/${patSecret}"
    fi

    GITHUB_PERSONAL_ACCESS_TOKEN="$(xargs <"$SECRET_FILE")"
    export GITHUB_PERSONAL_ACCESS_TOKEN
    exec github-mcp-server stdio
  '';

  meta = {
    inherit (super.github-mcp-server.meta) description homepage;
    platforms = super.lib.platforms.all;
  };
}
