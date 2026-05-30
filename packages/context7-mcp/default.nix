{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_10,
  nodejs,
  openssl,
}: let
  pname = "context7-mcp";
  version = "3.0.0";
  src = fetchFromGitHub {
    owner = "upstash";
    repo = "context7";
    rev = "@upstash/context7-mcp@3.0.0";
    hash = "sha256-3Hk3YEXIR6SAEtCeDeaU1fU/CyvxuObZSNbgqrzeJ/o=";
  };
in
  stdenv.mkDerivation {
    inherit pname version src;

    nativeBuildInputs = [
      openssl
      pnpmConfigHook
      pnpm_10
    ];

    propagatedBuildInputs = [
      nodejs
    ];

    pnpmWorkspaces = ["packages/mcp"];

    pnpmDeps = fetchPnpmDeps {
      inherit pname version src;
      pnpm = pnpm_10;
      hash = "sha256-ugUN1U0OR8dPTq4PADJaq6ElngSlw6PlmYDUFoW+2F4=";
      fetcherVersion = 3;
    };

    buildPhase = ''
      runHook preBuild
      ${./build.sh}
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      ${./install.sh}
      runHook postInstall
    '';

    meta = with lib; {
      description = "Context7 MCP provides up-to-date code documentation for LLMs";
      homepage = "https://github.com/upstash/context7";
      license = licenses.mit;
      platforms = platforms.unix;
    };
  }
