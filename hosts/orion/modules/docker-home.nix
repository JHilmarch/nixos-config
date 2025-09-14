# Home Manager: rootless Docker client defaults
# - Sets DOCKER_HOST to the per-user rootless socket.
# - Ensures a "rootless" Docker context exists and is the default.
# Safe to run repeatedly; no-op if Docker is missing.
{
  config,
  pkgs,
  lib,
  ...
}: {
  home.sessionVariables = {
    DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/docker.sock";
  };

  home.activation.dockerRootlessContext = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if command -v docker >/dev/null 2>&1; then
      if ! docker context ls --format '{{.Name}}' 2>/dev/null | grep -qx rootless; then
        docker context create rootless --docker "host=unix:///run/user/$(id -u)/docker.sock" || true
      fi
      current_ctx=$(docker context show 2>/dev/null || echo default)
      if [ "$current_ctx" != "rootless" ]; then
        docker context use rootless || true
      fi
    fi
  '';
}
