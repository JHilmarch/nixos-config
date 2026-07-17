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
      # --no-config is load-bearing: a plain `fish -c` / `fish <script>` re-runs
      # NixOS's fish preinit, which rebuilds $PATH from the profile dirs and drops
      # the inherited runtimeInputs prefix (github-project-manager lives only
      # there inside the opencode sandbox). --no-config keeps the inherited PATH,
      # and runtimeInputs above pins gh + jq regardless of the calling shell.
      exec fish --no-config ${src}/project-manager/project-manager.fish "$@"
    '';
  }
