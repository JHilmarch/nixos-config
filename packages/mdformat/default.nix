{python3}:
# mdformat bundled with the GFM + frontmatter plugins required by
# `.mdformat.toml`'s `extensions = ["gfm", "frontmatter"]` rule.
#
# Why this package exists: bare `pkgs.mdformat` ships only the CommonMark
# core. Without `mdformat-gfm`, GFM tables are parsed as paragraph text and
# `wrap = 120` (set in .mdformat.toml) splits each table row across multiple
# physical lines — destroying the table (every GFM table row MUST be a single
# line). Without `mdformat-frontmatter`, YAML frontmatter (used by every
# `SKILL.md`) gets mangled.
#
# Use this anywhere `mdformat` is exposed to user/agent shells:
#   - hosts/{orion,p51}/home.nix       — user daily shell
#   - home-modules/opencode/default.nix — agent sandbox (nono runtime inputs)
#
# When the plugin set needs to change (e.g. add mdformat-toc), update both
# this file AND treefmt.nix to keep them in sync.
python3.withPackages (ps: [
  ps.mdformat
  ps.mdformat-gfm
  ps.mdformat-frontmatter
])
