{
  lib,
  pkgs,
  nodejs,
}: let
  pname = "azure-devops-mcp";
  version = "2.4.0";
in
  pkgs.buildNpmPackage {
    inherit pname version nodejs;

    src = pkgs.fetchFromGitHub {
      owner = "microsoft";
      repo = "azure-devops-mcp";
      rev = "v${version}";
      hash = "sha256-I5EOPTxWJcfPV8I1Lwvyj3ljo8Y9W7GojtTWCAreU/g=";
    };

    npmDepsHash = "sha256-zr6k0ZaE/TZpgSW/FB2zX61t09h8t0xyJyxuaURrCkI=";

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
