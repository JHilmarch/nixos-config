{pkgs, ...}: {
  modules.copilot-cli = {
    enable = true;

    runtimeInputs = [
      pkgs.nodejs_24
      (pkgs.dotnetCorePackages.combinePackages [
        pkgs.dotnetCorePackages.dotnet_9.sdk
        pkgs.dotnetCorePackages.dotnet_10.sdk
      ])
    ];

    mcpServers = {
      azure-devops = {
        command = "copilot-azure-devops-mcp";
        tools = ["*"];
      };
    };
  };
}
