{awesome-copilot}:
awesome-copilot.overrideAttrs (prev: {
  buildPhase = ''
    source ${awesome-copilot.passthru.buildPhase'}
    buildPhase true
  '';

  meta =
    prev.meta
    // {
      description = "Awesome Copilot MCP packaged with a .NET 9 wrapper (with MCP logging patch applied)";
    };
})
