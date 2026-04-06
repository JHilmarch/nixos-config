{
  lib,
  writeShellApplication,
  findutils,
  gh,
  serviceName,
  patSecret,
}:
writeShellApplication {
  name = serviceName;

  runtimeEnv = {
    PATH = lib.strings.makeBinPath [
      findutils
      gh
    ];
  };

  text = ''
    GH_TOKEN="$(xargs </run/secrets/${patSecret})"
    export GH_TOKEN
    exec gh "$@"
  '';

  meta = {
    description = "GitHub CLI authenticated via ${patSecret}";
    platforms = lib.platforms.all;
  };
}
