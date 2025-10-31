# Project Guidelines

These guidelines tell Junie how to work in this repository.

- This repo is a Nix configuration using flakes for NixOS hosts.

  - Current hosts: orion and iso (installer image). See the main README in the repo root for details and structure:
    ./README.md
  - Key files/dirs: flake.nix, flake.lock, hosts/{orion,iso}/, modules/, home-modules/, functions/, scripts/, secrets/

- Always validate changes against the local NixOS MCP

  - The local MCP is defined in .junie/mcp/mcp.json under the key "nixos"
  - Use it to check correctness and get guidance for Nix/NixOS-specific questions.
  - If MCP is unavailable, ask the user to run it locally and report back results.

- Ask the user to test or rebuild before committing to Git only when .nix files are changed:

  - If any .nix file was modified in this session, explicitly prompt the user to perform a local test build before
    finalizing changes or asking to commit.
  - Suggested commands (run from repo root):
    - nix flake check
    - sudo nixos-rebuild test --flake .
    - For the installer target: see hosts/iso/README-iso.md; typically: nix build
      .#nixosConfigurations.iso.config.system.build.isoImage (or follow README instructions).
  - If any command fails, request the full output and adjust the changes accordingly.
  - If no .nix files were changed, do not ask the user to run these commands.

- General workflow for Junie

  - Consult ./README.md for project structure and host targets before making changes.
  - Make minimal, targeted edits; prefer updating host-specific files under hosts/{host}/ when possible.
  - Do not commit; leave committing to the user after a successful local test build.
  - Document findings and next steps in the session status updates.

- Git commits

  - Use Conventional Commits.
  - Subject line must be at most 50 characters.
  - Leave a blank line between subject and body.
  - The body lines should be at most 72 characters.

- Terminal

  - When giving guidelines for commands to be used in the Terminal, make them available to be run in fish shell.
