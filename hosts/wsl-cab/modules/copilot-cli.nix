{
  pkgs,
  ...
}: {
  modules.copilot-cli = {
    runtimeInputs = [
      pkgs.local.azure-devops-mcp
    ];

    mcpServers = {
      azure-devops = {
        command = "copilot-azure-devops-mcp";
        tools = ["*"];
      };
    };
  };
}
