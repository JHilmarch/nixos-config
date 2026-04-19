# Contributing guidelines

Please follow the steps below before committing.

## 1) Format changed files

Use `nix fmt` (powered by treefmt) to format all file types consistently.

- Format only staged files (recommended):

  ```bash
  nix fmt -- --staged
  ```

- Format the whole repo:

  ```bash
  nix fmt
  ```

This runs the following formatters automatically:

- **alejandra** for `.nix` files
- **mdformat** for `.md` files
- **fish_indent** for `.fish` files
- **biome** for `.js`, `.ts`, `.json`, `.css`, `.html` files (format + lint)

Formatting is also validated by `nix flake check`.

## 2) Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/). Keep the subject concise (≤ 50 chars), leave a blank
line, and wrap the body before 72 chars.

Examples:

- feat(orion): add systemd no-sleep module
- fix(nfs): correct exports for fileshare

## 3) Nix-specific checks

When you change .nix files, validate locally before pushing (see README for host targets):

- flake checks

  ```bash
  nix flake check
  ```

- NixOS test build for your host (example):

  ```bash
  sudo nixos-rebuild test --flake .
  ```

- Installer image (see hosts/iso/README-iso.md), e.g.:

  ```bash
  nix build .#nixosConfigurations.iso.config.system.build.isoImage
  ```

If any command fails, review the output, fix the issue, and re-run.

## 4) MCP helper (optional but recommended)

This repo is set up to use a local NixOS MCP helper (see `mcp.json`). If available on your machine, Junie can run it for
guidance and validation.

See the main README for repository structure and additional guidelines.
