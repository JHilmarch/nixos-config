{
  lib,
  writeShellApplication,
  fish,
  jq,
  coreutils,
  github-project-manager,
}: let
  # The script self-locates via `status filename` and sources ../common/log.fish,
  # so the store copy must preserve the tools/ layout: both project-manager/
  # and common/ under the same root.
  src = lib.fileset.toSource {
    root = ../../tools;
    fileset = lib.fileset.unions [
      ../../tools/project-manager
      ../../tools/common
    ];
  };
in
  writeShellApplication {
    name = "project-manager";
    # coreutils: the script shells out to dirname/mktemp/cat (self-location + stdin body).
    # jq + github-project-manager: the CLI's own runtime deps. fish: the interpreter.
    runtimeInputs = [fish jq coreutils github-project-manager];
    checkPhase = "true"; # repo convention for wrappers
    text = ''
      # Forgejo REST credential — silently empty if secret absent (e.g., host without
      # forgejo-pat). The forgejo backend's check_prerequisites catches an empty token
      # with a clear error.
      FORGEJO_TOKEN="$(xargs </run/secrets/forgejo-pat 2>/dev/null || true)"
      export FORGEJO_TOKEN
      # Forgejo web-session credentials (bot account) — needed only for project-board
      # (GUI-emulation) ops, which Forgejo exposes via the web UI, not the REST API.
      # Silently empty if absent; board ops then fail with a clear "web session
      # required" error while REST ops keep working.
      # Read raw (command substitution already strips trailing newlines) rather
      # than xargs: a password may contain quotes/backslashes/spaces that xargs
      # would mangle.
      FORGEJO_WEB_USER="$(cat /run/secrets/forgejo-web-user 2>/dev/null || true)"
      FORGEJO_WEB_PASS="$(cat /run/secrets/forgejo-web-pass 2>/dev/null || true)"
      export FORGEJO_WEB_USER FORGEJO_WEB_PASS
      # --no-config is load-bearing: a plain `fish -c` / `fish <script>` re-runs
      # NixOS's fish preinit, which rebuilds $PATH from the profile dirs and drops
      # the inherited runtimeInputs prefix (github-project-manager lives only
      # there inside the opencode sandbox). --no-config keeps the inherited PATH,
      # and runtimeInputs above pins gh + jq regardless of the calling shell.
      exec fish --no-config ${src}/project-manager/project-manager.fish "$@"
    '';
  }
