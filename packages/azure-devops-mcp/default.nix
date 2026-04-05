{
  lib,
  pkgs,
  nodejs,
}: let
  pname = "azure-devops-mcp";
  version = "2.5.0";
in
  pkgs.buildNpmPackage {
    inherit pname version nodejs;

    src = pkgs.fetchFromGitHub {
      owner = "microsoft";
      repo = "azure-devops-mcp";
      rev = "v${version}";
      hash = "sha256-tIIPKjxAp5+rnl+WCfGaSlMt71A+v2Saq/E+pinBJqU=";
    };

    npmDepsHash = "sha256-I8eCzTXjOw+91aOTcO5L5Ha4s59E2oJ69jpl+8aZij8=";

    postInstall = ''
      mv $out/bin/mcp-server-azuredevops $out/bin/azure-devops-mcp
    '';

    meta = with lib; {
      description = "Azure DevOps MCP Server (Microsoft)";
      homepage = "https://github.com/microsoft/azure-devops-mcp";
      license = lib.licenses.mit;
      mainProgram = "azure-devops-mcp";
    };
  }
