# Contributing guidelines

Please follow the steps below before committing.

## 1) Format/lint changed files with alejandra

Use alejandra (Nix formatter) to keep the style consistent. Always format the
changed .nix files before committing.

- Format only the staged/changed .nix files (recommended):

  ```bash
  git diff --name-only --cached -- '*.nix' | xargs -r alejandra -q
  ```

- Or format the whole repo:

  ```bash
  alejandra .
  ```

[alejandra on GitHub](https://github.com/kamadorueda/alejandra)

## 2) Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/). Keep the subject concise (≤ 50 chars), leave a blank
line, and wrap the body at ~72 chars.

Examples:
- feat(orion): add systemd no-sleep module
- fix(nfs): correct exports for fileshare

## 3) Nix-specific checks (when .nix files change)

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

This repo is set up to use a local NixOS MCP helper (see `mcp.json`). If
available on your machine, Junie can run it for guidance and validation.

See the main README for repository structure and additional guidelines.
