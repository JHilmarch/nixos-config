self: super: {
  github-personal-mcp = import ./personal.nix {inherit self super;};
  github-work-mcp = import ./work.nix {inherit self super;};
}
