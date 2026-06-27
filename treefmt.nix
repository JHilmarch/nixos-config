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

  # Global excludes — never touch encrypted/generated/skill files.
  # Skill SKILL.md files have YAML frontmatter that mdformat mangles
  # (collapses "---\nname: foo\n---" into "___\n## name: foo"). Both
  # `ai/skills/` (user-scope, installed via readSkillsFrom) and
  # `.claude/skills/` (project-scope, scanned natively by opencode +
  # Claude Code) hold skills and must be excluded identically.
  settings.excludes = [
    "secrets/*"
    "*.age"
    "ai/skills/*"
    ".claude/skills/*"
  ];
}
