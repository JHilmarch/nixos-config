{
  lib,
  runCommand,
  fetchFromGitHub,
  buildNpmPackage,
  nodejs_24,
  python3,
  pkg-config,
  vips,
}: let
  pname = "openchamber";
  version = "1.13.8";

  src = runCommand "${pname}-${version}-src" {} ''
    mkdir "$out"
    cp -r ${fetchFromGitHub {
      owner = "openchamber";
      repo = "openchamber";
      rev = "v${version}";
      hash = "sha256-ordjE7BLOnX2UeVGmOHT6DoOPTgn0pD67+WlxILEUKo=";
    }}/. "$out"
    chmod -R +w "$out"

    cp ${./package-lock.json} "$out/package-lock.json"

    ${nodejs_24}/bin/node -e '
      const fs = require("fs");
      const packageJsonPath = process.argv[1];
      const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));
      packageJson.workspaces = ["packages/ui", "packages/web"];
      fs.writeFileSync(packageJsonPath, JSON.stringify(packageJson, null, 2) + "\n");
    ' "$out/package.json"
  '';
in
  buildNpmPackage {
    inherit pname version src;
    nodejs = nodejs_24;

    npmDepsHash = "sha256-rMVDFzPJv/drhrdf3L7yY+/RE9AdsaMWOBHWe/85hQQ=";
    npmWorkspace = "packages/web";
    npmPruneFlags = ["--include-workspace-root=false"];
    makeCacheWritable = true;
    SHARP_FORCE_GLOBAL_LIBVIPS = "true";

    nativeBuildInputs = [
      python3
      pkg-config
    ];

    buildInputs = [vips];

    postInstall = ''
      rm -f \
        "$out/lib/node_modules/openchamber-monorepo/node_modules/.bin/openchamber" \
        "$out/lib/node_modules/openchamber-monorepo/node_modules/@openchamber/ui" \
        "$out/lib/node_modules/openchamber-monorepo/node_modules/@openchamber/web"

      mkdir -p "$out/bin"
      cat > "$out/bin/openchamber" <<WRAPPER
      #!${lib.getExe' nodejs_24 "node"}
      const {spawn} = require("node:child_process");

      const child = spawn(
        ${builtins.toJSON (lib.getExe' nodejs_24 "node")},
        [${builtins.toJSON "$out/lib/node_modules/openchamber-monorepo/bin/cli.js"}, ...process.argv.slice(2)],
        {stdio: "inherit"},
      );

      child.on("exit", (code, signal) => {
        if (signal !== null) {
          process.kill(process.pid, signal);
          return;
        }

        process.exit(code ?? 0);
      });
      WRAPPER
      chmod +x "$out/bin/openchamber"
    '';

    meta = with lib; {
      description = "Desktop and web interface for OpenCode AI agent";
      homepage = "https://github.com/openchamber/openchamber";
      license = licenses.mit;
      mainProgram = "openchamber";
      platforms = platforms.unix;
    };
  }
