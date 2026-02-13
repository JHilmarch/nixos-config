{
  lib,
  stdenv,
  fetchFromGitHub,
  pnpm_10,
  nodejs,
  openssl,
}: let
  pname = "context7-mcp";
  version = "2.1.1";
  src = fetchFromGitHub {
    owner = "upstash";
    repo = "context7";
    rev = "@upstash/context7-mcp@2.1.1";
    hash = "sha256-xAdONUfiJoLbhq/zhOgxuqJN7BkfaQKz3X9ApN/ASP4=";
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
      hash = "sha256-rA7E21WwwfIPyb05hL7RIbnbC8wfW82DexApOa4Vt6g=";
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
