self: super: let
  lib = super.lib;
in {
  awesome-copilot = super.stdenvNoCC.mkDerivation rec {
    pname = "awesome-copilot";
    version = "unstable-2025-12-14";

    src = super.fetchFromGitHub {
      owner = "github";
      repo = "awesome-copilot";
      rev = "ac93f988c4dcae2c9de8ec56ed357750834c5cd2";
      hash = "sha256-Z42ymxEjYH+OMDcdTYT6Pvf7gFdGmSW8er8Xa3bRDL8=";
    };

    installPhase = ''
      runHook preInstall

      # Docs location
      docDir=$out/share/doc/awesome-copilot
      mkdir -p "$docDir"

      # Copy top-level docs
      cp -r . "$docDir/"

      # Provide a simple viewer script
      mkdir -p $out/bin
      cat > $out/bin/awesome-copilot << 'EOF'
      #!/usr/bin/env bash
      set -euo pipefail
      DOC_ROOT="$(${super.coreutils}/bin/realpath "$(dirname "$0")/../share/doc/awesome-copilot")"
      README="$DOC_ROOT/README.md"
      if [ -t 1 ] && command -v mdcat >/dev/null 2>&1; then
        exec mdcat "$README"
      else
        exec ${super.less}/bin/less -R "$README"
      fi
      EOF
      chmod +x $out/bin/awesome-copilot

      runHook postInstall
    '';

    meta = with super.lib; {
      description = "A curated list of awesome GitHub Copilot resources";
      homepage = "https://github.com/github/awesome-copilot";
      license = licenses.mit;
      platforms = platforms.all;
      maintainers = [];
    };
  };
}
