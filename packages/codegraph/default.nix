{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
}:
# codegraph — local-first code-intelligence MCP server (colbymchenry/codegraph),
# exposed to the opencode/oh-my-openagent sandbox as `pkgs.local.codegraph`.
#
# Why a prebuilt bundle (not buildNpmPackage): upstream ships the official CLI
# only as a per-platform tarball that vendors its own Node runtime. The npm
# package `@colbymchenry/codegraph` is a thin shim that resolves the
# platform-specific `@colbymchenry/codegraph-<os>-<arch>` bundle at runtime.
# We fetch that bundle directly from the GitHub release — byte-for-byte the same
# content as the npm platform package, without npm optional-dependency
# resolution.
#
# The bundle is `bin/codegraph` (POSIX launcher) → `node` (vendored ELF) →
# `lib/dist/bin/codegraph.js` (compiled app). The launcher execs the vendored
# node with `--liftoff-only`, so the whole tree must stay together and only the
# `node` ELF needs patching (generic-glibc interpreter + libstdc++/libgcc).
#
# OMO's resolver (packages/utils/src/codegraph/resolve.ts) enables the MCP when
# it finds `codegraph` on PATH (source "path", gated on a supported Node) or via
# the `OMO_CODEGRAPH_BIN` env var (source "env", no Node-version gate). The host
# opencode module points `OMO_CODEGRAPH_BIN` at `${codegraph}/bin/codegraph`.
#
# Version bumps: update `version` + `hash` (the linux-x64 release tarball's SRI).
stdenv.mkDerivation rec {
  pname = "codegraph";
  version = "1.1.6";

  src = fetchurl {
    url = "https://github.com/colbymchenry/codegraph/releases/download/v${version}/codegraph-linux-x64.tar.gz";
    hash = "sha256-+rfx9stB8oJkiLRBHy68Ntp5km0ryg04IPT1EKvP0UM=";
  };

  nativeBuildInputs = [autoPatchelfHook makeWrapper];

  # The vendored `node` ELF NEEDs libstdc++.so.6 + libgcc_s.so.1 (both from
  # stdenv.cc.cc.lib); libc/libm/libdl/libpthread come from glibc via the hook.
  buildInputs = [stdenv.cc.cc.lib];

  # Bundle is a plain tarball of a directory; nothing to build.
  dontConfigure = true;
  dontBuild = true;

  installPhase = builtins.readFile ./install.sh;

  meta = {
    description = "Local-first code-intelligence knowledge graph exposed over MCP";
    homepage = "https://github.com/colbymchenry/codegraph";
    license = lib.licenses.mit;
    platforms = ["x86_64-linux"];
    mainProgram = "codegraph";
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
}
