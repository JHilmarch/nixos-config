{
  lib,
  stdenv,
  fetchFromGitHub,
  pnpm_10,
  nodejs,
  openssl,
}: let
  pname = "context7-mcp";
  version = "2.2.3";
  src = fetchFromGitHub {
    owner = "upstash";
    repo = "context7";
    rev = "@upstash/context7-mcp@2.2.3";
    hash = "sha256-Vse6mOfzDC65V3qoL1tZu5S9DU93PmVNI8NRm94Gcn8=";
  };
in
  stdenv.mkDerivation {
    inherit pname version src;

    nativeBuildInputs = [
      openssl
      pnpm_10.configHook
    ];

    propagatedBuildInputs = [
      nodejs
    ];

    pnpmWorkspaces = "packages/mcp";

    pnpmDeps = pnpm_10.fetchDeps {
      inherit pname version src;
      hash = "sha256-Cuh2Ux07jndcmEOH2CkbNlqkVEcabmntv2mbXhjfUhE=";
      fetcherVersion = 1;
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
