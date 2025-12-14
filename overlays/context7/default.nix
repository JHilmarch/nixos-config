self: super: let
  lib = super.lib;
in {
  context7 = super.buildNpmPackage {
    pname = "context7";
    version = "1.0.30";

    src = super.fetchFromGitHub {
      owner = "upstash";
      repo = "context7";
      rev = "v1.0.30";
      hash = "sha256-cNm/NROFHy+3cOozzvC1WUhGb7bwccvOIiMt30lAN3E=";
    };

    # Copy vendored lockfile so buildNpmPackage can prefetch dependencies
    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';

    # Pinned from build output (wanted)
    npmDepsHash = "sha256-alv+o6II9qZWsGzV9wuWZQZsMnTdJIqYtBTDlbG9xH8=";

    buildPhase = ''
      runHook preBuild
      npm run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      cp -r dist $out/
      cp -r node_modules $out/

      # Create wrapper script
      cat > $out/bin/context7 << EOF
      #!/bin/sh
      exec ${super.nodejs}/bin/node $out/dist/index.js "\$@"
      EOF

      chmod +x $out/bin/context7

      runHook postInstall
    '';

    meta = with super.lib; {
      description = "Context7 MCP provides up-to-date code documentation for LLMs";
      homepage = "https://github.com/upstash/context7";
      license = licenses.mit;
      platforms = platforms.unix;
    };
  };
}
