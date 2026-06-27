---
name: update-packages
description: Update custom packages to their latest versions
disable-model-invocation: true
allowed-tools: Bash, Read, Edit, Glob, Grep
---

## How to use the CLI

```bash
fish tools/update-packages/update-packages.fish --help
```

Important: always use the --json flag.

## Instructions

1. Read the help
1. List to see what needs updating
1. Parse the output to determine which packages are outdated
1. Run the update for the desired packages
1. If a package update fails:
   - Read the error output
   - Investigate the root cause (common: API changes, hash format mismatch, version scheme change)
   - Fix and retry
1. After all updates succeed:
   - Format changed Nix files: `alejandra packages/ modules/`
   - Verify: `nix flake check`
   - Do NOT commit unless the user asks
