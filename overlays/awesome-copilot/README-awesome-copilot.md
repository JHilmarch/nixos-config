# Awesome Copilot overlay

This overlay packages the [Awesome Copilot](https://github.com/microsoft/mcp-dotnet-samples/tree/main/awesome-copilot)
MCP server from the [microsoft/mcp-dotnet-samples](https://github.com/microsoft/mcp-dotnet-samples) repository and
exposes a CLI named `awesome-copilot` that runs on .NET 9.

The overlay pins all transitive NuGet packages in `deps.json`. You must regenerate this file whenever bumping the source
revision.

## Build targets

- Package: `.#awesome-copilot`

## Bump version and rebuild

1. Pick the new commit/revision from GitHub: https://github.com/microsoft/mcp-dotnet-samples

1. Clone the repository (or update your existing clone) and checkout the desired revision.

1. Regenerate the pinned dependencies for this overlay using the helper script. This step is required, otherwise the
   build will fail or use stale dependencies.

   Bash command:

   - `bash scripts/generate-nuget-deps-from-project.sh /path/to/mcp-dotnet-samples/awesome-copilot/src/McpSamples.AwesomeCopilot.HybridApp overlays/awesome-copilot/deps.json"`

   The script runs `dotnet restore` on the project file, computes sha256 for each package from nuget.org and writes them
   to `overlays/awesome-copilot/deps.json`.

1. Update `overlays/awesome-copilot/default.nix` with the new revision and hash:

   - Update the `rev` field with the new commit hash.
   - Update the `hash` by temporarily setting the hash to `lib.fakeHash` and letting the build fail with the correct
     hash).

1. Build the package:

   - `nix build .#awesome-copilot`

1. Test run from the build result:

   - `./result/bin/awesome-copilot`

Notes:

- Review the diff of `deps.json` and `default.nix` into version control once verified.
