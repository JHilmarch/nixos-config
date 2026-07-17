# packages/AGENTS.md

Custom packages exposed as `pkgs.local.<name>` via overlay (orion, p51, and wsl-cab only).

## Structure

```
packages/
├── default.nix              # Registry: callPackages, 12 exports
├── azure-devops-mcp/        # buildNpmPackage of microsoft/azure-devops-mcp
├── azure-mcp-server/        # NuGet .NET tool, deps.json, dotnet dnx wrapper
├── github-mcp-server/       # Base/variant: personal + work PAT injection
│   ├── base.nix             # Takes serviceName + patSecret
│   ├── personal.nix         # github-personal-mcp (reads gh_personal_pat)
│   ├── work.nix             # github-work-mcp (reads gh_work_pat)
│   └── gh-cli.nix           # github-mcp-server via `gh auth token`
├── gh-cli/                  # Base/variant: GitHub CLI account wrappers with PAT injection
│   ├── base.nix             # Takes serviceName + patSecret
│   ├── personal.nix         # gh-personal
│   └── work.nix             # gh-work
└── project-manager/         # Backend-agnostic Projects CLI + per-forge PAT wrappers
    ├── default.nix          # project-manager (fish CLI; GitHub + Forgejo backends)
    ├── github.nix           # github-project-manager (reuses gh-cli/base.nix, gh_personal_project_pat)
    ├── forgejo-base.nix     # Takes serviceName + patSecret; injects FORGEJO_TOKEN
    └── forgejo.nix          # forgejo-project-manager (reads forgejo-pat)
```

## Where to Look

- **Add a new package** → create `packages/<name>/default.nix` — register in `packages/default.nix`
- **Update package version** → `tools/update-packages/packages/<name>.fish` — Fish CLI updater
- **Fix NuGet deps** → `packages/<name>/deps.json` — run `generate-nuget-deps.sh` to regenerate
- **Add personal/work split** → copy `github-mcp-server/` pattern — base + variant files
- **Fix hash mismatch** → set hash to empty string, rebuild, copy correct hash — `lib/nix.fish` automates this

## Package Patterns

### Base/Variant (personal/work split)

Base module takes `serviceName` and `patSecret` as arguments. Variants call base with specific values. Used by:
`github-mcp-server/`, `gh-cli/`, `project-manager/` (its `github.nix` reuses `gh-cli/base.nix`; `forgejo-base.nix` is
its own base)

### NuGet (.NET tools)

`deps.json` lists nupkg URLs + hashes. Build extracts and wraps with `dotnet dnx`. Throws helpful error if `deps.json`
is empty with regeneration instructions. Used by: `azure-mcp-server/`

### Node.js

`buildNpmPackage` or `stdenv.mkDerivation` with external build.sh/install.sh. Used by: `azure-devops-mcp/` (npm)

## Conventions

- All packages registered in `packages/default.nix` via `callPackage`
- PAT injection: wrappers read `/run/secrets/<secretName>` at runtime (SOPS-managed)
- Package names: kebab-case, prefixed by purpose (e.g., `github-personal-mcp`)
- `deps.json` files must be regenerated when NuGet package versions change
- Update tool: `tools/update-packages/packages/<name>.fish` per package

## Anti-Patterns

- **NEVER** hardcode PATs or API keys in package definitions
- **NEVER** edit `deps.json` manually — use `tools/update-packages/scripts/generate-nuget-deps.sh`
- **NEVER** forget to register new packages in `packages/default.nix`
- **NEVER** assume `pkgs.local.*` is available on all hosts — only orion, p51, and wsl-cab
