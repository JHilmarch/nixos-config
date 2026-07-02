{pkgs, ...}: {
  projectRootFile = "flake.nix";

  # Nix
  programs.alejandra.enable = true;

  # Markdown — with plugins so YAML frontmatter (skill SKILL.md files) and
  # GFM tables are preserved instead of mangled into horizontal rules / inline.
  programs.mdformat = {
    enable = true;
    plugins = ps: [
      ps.mdformat-frontmatter
      ps.mdformat-gfm
    ];
  };

  # Fish
  programs.fish_indent.enable = true;

  # Web ecosystem (JS/TS/JSON/CSS/HTML) — format + lint
  programs.biome.enable = true;
  programs.biome.formatCommand = "check";
  programs.biome.validate.enable = false; # Schema hash mismatch with Biome v2.4.10
  programs.biome.settings = builtins.fromJSON (builtins.readFile ./biome.json);
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

  # Global excludes — never touch encrypted files.
  # Note: skill SKILL.md files no longer need an explicit exclude now that
  # mdformat-frontmatter preserves their YAML frontmatter.
  settings.excludes = [
    "secrets/*"
    "*.age"
  ];
}
