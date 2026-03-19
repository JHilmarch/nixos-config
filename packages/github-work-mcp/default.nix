{
  lib,
  symlinkJoin,
  github-mcp-server,
  makeWrapper,
}: let
  name = "github-work-mcp";
in
  symlinkJoin {
    inherit name;
    paths = [github-mcp-server];
    buildInputs = [makeWrapper];

    postBuild = ''
      rm -f "$out/bin/github-mcp-server"
      makeWrapper ${github-mcp-server}/bin/github-mcp-server "$out/bin/${name}" \
        --run '
          token_file=""
          for f in \
            "''${XDG_RUNTIME_DIR}/secrets/gh_work_pat" \
            "/run/user/$(id -u)/secrets/gh_work_pat" \
            "/run/secrets/gh_work_pat"
          do
            if [ -r "$f" ]; then
              token_file="$f"
              break
            fi
          done

          if [ -z "$token_file" ]; then
            echo "github-work-mcp: error: could not find readable token file." >&2
            echo "Checked paths:" >&2
            echo "  - ''${XDG_RUNTIME_DIR:-<unset>}/secrets/gh_work_pat" >&2
            echo "  - /run/user/$(id -u)/secrets/gh_work_pat" >&2
            echo "  - /run/secrets/gh_work_pat" >&2
            exit 1
          fi

          echo "github-work-mcp: using token from $token_file" >&2
          GITHUB_PERSONAL_ACCESS_TOKEN="$(tr -d "\n\r" < "$token_file")"
          export GITHUB_PERSONAL_ACCESS_TOKEN
        '
    '';

    meta = with lib; {
      description = "GitHub MCP server wrapper for work account";
      platforms = platforms.unix;
    };
  }
