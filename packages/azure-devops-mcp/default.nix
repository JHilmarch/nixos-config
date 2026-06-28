{
  lib,
  pkgs,
  nodejs,
}: let
  pname = "azure-devops-mcp";
  version = "2.8.0";
in
  pkgs.buildNpmPackage {
    inherit pname version nodejs;

    src = pkgs.fetchFromGitHub {
      owner = "microsoft";
      repo = "azure-devops-mcp";
      rev = "v${version}";
      hash = "sha256-Ds/Kcr4xb9f7i9hPiunSTfn8rwgorqzpWvT1jIoSIYk=";
    };

    npmDepsHash = "sha256-tqAHcEl3mjHY5cI5rhSJa0SSvyvUHrwVxyN2CFdNMK4=";

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
