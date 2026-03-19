{
  lib,
  symlinkJoin,
  github-mcp-server,
  makeWrapper,
  name,
  tokenFileName,
  description,
}:
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
          "''${XDG_RUNTIME_DIR}/secrets/${tokenFileName}" \
          "/run/user/$(id -u)/secrets/${tokenFileName}" \
          "/run/secrets/${tokenFileName}"
        do
          if [ -r "$f" ]; then
            token_file="$f"
            break
          fi
        done

        if [ -z "$token_file" ]; then
          echo "${name}: error: could not find readable token file." >&2
          echo "Checked paths:" >&2
          echo "  - ''${XDG_RUNTIME_DIR:-<unset>}/secrets/${tokenFileName}" >&2
          echo "  - /run/user/$(id -u)/secrets/${tokenFileName}" >&2
          echo "  - /run/secrets/${tokenFileName}" >&2
          exit 1
        fi

        echo "${name}: using token from $token_file" >&2
        GITHUB_PERSONAL_ACCESS_TOKEN="$(tr -d "\n\r" < "$token_file")"
        export GITHUB_PERSONAL_ACCESS_TOKEN
      '
  '';

  meta = with lib; {
    inherit description;
    platforms = platforms.unix;
  };
}
