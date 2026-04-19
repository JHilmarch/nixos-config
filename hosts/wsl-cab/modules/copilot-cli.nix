{pkgs, ...}: {
  modules.copilot-cli = {
    enable = true;

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
