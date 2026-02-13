# Azure DevOps MCP Server

This package provides [Azure DevOps MCP Server](https://github.com/microsoft/azure-devops-mcp) for interacting with
Azure DevOps from LLMs.

## Build targets

- Package: `.#azure-devops-mcp` (or `.#packages.x86_64-linux.azure-devops-mcp` for full)

## Usage

The binary `azure-devops-mcp` requires an Azure DevOps organization name as argument:

```fish
# List projects in your org
azure-devops-mcp my-org

# With domain filtering
azure-devops-mcp my-org -d core,work,work-items

# Show help
azure-devops-mcp --help
```

### Domain Filtering

The Azure DevOps MCP Server supports filtering by domains to load only areas you need:

- `core` - Core functionality (always recommended)
- `work` - Work tracking
- `work-items` - Work item management
- `search` - Search functionality
- `test-plans` - Test planning
- `repositories` - Repository operations
- `wiki` - Wiki operations
- `pipelines` - Pipeline management
- `advanced-security` - Advanced security features

Add `-d` with domain names to limit loaded tools:

```fish
azure-devops-mcp my-org -d core,work,work-items
```

## Bump version and rebuild

1. Check latest version: https://www.npmjs.com/package/@azure-devops/mcp
1. Update version in `packages/azure-devops-mcp/default.nix`
1. Get new hashes (change version and reset hashes to dummy values first):
   ```fish
   # In packages/azure-devops-mcp/default.nix, set:
   # version = "x.y.z";
   # hash = lib.fakeHash;
   # npmDepsHash = lib.fakeHash;

   nix build .#azure-devops-mcp
   ```
1. Update `hash` and `npmDepsHash` values from the error messages.
1. Build:
   ```fish
   nix build .#azure-devops-mcp
   ```

## Package details

- **Homepage**: https://github.com/microsoft/azure-devops-mcp
- **License**: MIT
- **Platforms**: All (Linux, macOS)
