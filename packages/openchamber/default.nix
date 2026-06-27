{
  lib,
  fetchurl,
  runCommand,
  buildNpmPackage,
  nodejs_22,
  python3,
  pkg-config,
  jq,
}: let
  pname = "openchamber";
  version = "1.13.5";

  # The published npm tarball for packages/web ships pre-built dist/, server/,
  # and bin/cli.js — no rebuild needed. We only install runtime deps.
  webTarball = fetchurl {
    url = "https://github.com/openchamber/openchamber/releases/download/v${version}/openchamber-web-${version}.tgz";
    hash = "sha256-0gKEC+j8X9io7DUXQYSi55D9YFPTp//5ua/eeE9u6ps=";
  };

  # Strip bun-pty (Bun-only; would break under Node) and drop in a
  # pre-generated lockfile so buildNpmPackage doesn't have to resolve one.
  src = runCommand "${pname}-${version}-src" {
    nativeBuildInputs = [jq];
  } ''
    mkdir -p $out
    tar -xzf ${webTarball} -C $out --strip-components=1
    chmod -R +w $out
    jq 'del(.dependencies."bun-pty")' $out/package.json > $out/package.json.tmp
    mv $out/package.json.tmp $out/package.json
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
  buildNpmPackage {
    inherit pname version src;
    nodejs = nodejs_22;

    npmDepsHash = "sha256-Quwj1k8gUSd09RiOeNU+QUBlqiTVqF8fwG/PXtMJbW8=";

    # Tarball already ships pre-built dist/ — skip npm run build.
    dontNpmBuild = true;
    npmFlags = ["--omit=dev" "--no-optional"];

    # node-pty and better-sqlite3 need native compilation via node-gyp.
    nativeBuildInputs = [
      python3
      pkg-config
    ];

    meta = with lib; {
      description = "Web GUI for OpenCode AI agent (multi-agent runs, worktrees, LAN access)";
      homepage = "https://github.com/openchamber/openchamber";
      license = licenses.mit;
      mainProgram = "openchamber";
      platforms = platforms.unix;
    };
  }
