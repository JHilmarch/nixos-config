self: super: let
  baseOverlay = import ./default.nix self super;
  basePackage = baseOverlay.awesome-copilot;
in {
  awesome-copilot = basePackage.overrideAttrs (prev: {
    buildPhase = ''
      source ${basePackage.passthru.buildPhase'}
      buildPhase true
    '';

    meta =
      prev.meta
      // {
        description = "Awesome Copilot MCP packaged via overlay with a .NET 9 wrapper (with MCP logging patch applied)";
      };
  });
}
