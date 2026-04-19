{
  lib,
  pkgs,
  nodejs,
}: let
  pname = "azure-devops-mcp";
  version = "2.6.0";
in
  pkgs.buildNpmPackage {
    inherit pname version nodejs;

    src = pkgs.fetchFromGitHub {
      owner = "microsoft";
      repo = "azure-devops-mcp";
      rev = "v${version}";
      hash = "sha256-uPyHHzB2Uqf38o2qya7mOydto7pL3aMPLO6qM/Lr9zc=";
    };

    npmDepsHash = "sha256-Hdx/9oiIouMrlw0KQVXaQgRjeVbCPgbyWm6lMBbTSQg=";

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
