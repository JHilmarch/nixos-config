# AI Skills

Shared skills used by multiple AI agents (Claude Code, OpenCode, GitHub Copilot CLI).

Each skill lives in its own directory containing a `SKILL.md` file. Skills are loaded declaratively by the agent's NixOS
home-manager module via `readSkillsFrom`.

To add a new shared skill:

1. Create `ai/skills/<skill-name>/SKILL.md`
1. The skill is automatically available to all agents configured to read from `ai/skills/`

Agent-specific skills that shouldn't be shared remain in their respective module directories (e.g.,
`home-modules/claude/skills/ck/` for Claude-only skills).
