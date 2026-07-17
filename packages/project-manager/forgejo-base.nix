{
  lib,
  writeShellApplication,
  project-manager,
  serviceName,
  patSecret,
}:
writeShellApplication {
  name = serviceName;
  runtimeInputs = [project-manager];
  checkPhase = "true";
  text = ''
    FORGEJO_TOKEN="$(xargs </run/secrets/${patSecret})"
    export FORGEJO_TOKEN
    exec project-manager --provider forgejo "$@"
  '';
  meta = {
    description = "Forgejo project manager CLI authenticated via ${patSecret}";
    platforms = lib.platforms.all;
  };
}
