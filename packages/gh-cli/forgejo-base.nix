{
  lib,
  writeShellApplication,
  gh-project-manager,
  serviceName,
  patSecret,
}:
writeShellApplication {
  name = serviceName;
  runtimeInputs = [gh-project-manager];
  checkPhase = "true";
  text = ''
    FORGEJO_TOKEN="$(xargs </run/secrets/${patSecret})"
    export FORGEJO_TOKEN
    export PROJECT_MANAGER_BACKEND=forgejo
    exec gh-project-manager "$@"
  '';
  meta = {
    description = "Forgejo project manager CLI authenticated via ${patSecret}";
    platforms = lib.platforms.all;
  };
}
