{pkgs, ...}: {
  projectRootFile = "flake.nix";

  # Nix
  programs.alejandra.enable = true;

  # Markdown
  programs.mdformat.enable = true;

  # Fish
  programs.fish_indent.enable = true;

  # Web ecosystem (JS/TS/JSON/CSS/HTML) — format + lint
  programs.biome.enable = true;
  programs.biome.formatCommand = "check";
  programs.biome.validate.enable = false; # Schema hash mismatch with Biome v2.4.10
  programs.biome.includes = [
    "*.js"
    "*.ts"
    "*.mjs"
    "*.mts"
    "*.cjs"
    "*.cts"
    "*.jsx"
    "*.tsx"
    "*.d.ts"
    "*.d.cts"
    "*.d.mts"
    "*.json"
    "*.jsonc"
    "*.css"
    "*.html"
  ];

  # Global excludes — never touch encrypted/generated/skill files
  settings.excludes = [
    "secrets/*"
    "*.age"
    "ai/skills/*"
  ];
}
