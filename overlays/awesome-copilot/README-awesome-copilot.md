# Awesome Copilot overlay

This overlay packages the GitHub "Awesome Copilot" collection https://github.com/github/awesome-copilot and installs its
docs under `$out/share/doc/awesome-copilot`. It also provides a tiny viewer CLI named `awesome-copilot` that opens the
top-level `README.md` using `mdcat` (if available) or `less -R`.

## Build targets

- Package: `.#awesome-copilot` (also available under `.#packages.${system}.awesome-copilot`)

## Quick start

- Build:
  - `nix build .#awesome-copilot`
- View docs from the build result:
  - `./result/bin/awesome-copilot`
  - or browse: `./result/share/doc/awesome-copilot/`

## How version pinning works

- Source is fetched from GitHub at a specific commit (`rev`) and pinned with a content hash (`hash`) via
  `fetchFromGitHub`.
- The overlay does not build software; it copies the upstream repo content into the Nix store for convenient offline
  browsing and reproducibility.

## Updating to a new upstream revision

1. Pick the new commit (or tag) from https://github.com/github/awesome-copilot and update these fields in
   `overlays/awesome-copilot/default.nix`:
   - `version` (e.g., `unstable-YYYY-MM-DD`)
   - `rev` (Git commit SHA or tag)
   - `hash` (content hash for `fetchFromGitHub`)
1. To refresh the `hash`, use the usual Nix "fake hash" workflow:
   - Temporarily set `hash = lib.fakeHash;`
   - Run: `nix build .#awesome-copilot`
   - Copy the "wanted" sha256 from the error output into `hash`.
1. Build again to verify it is clean:
   - `nix build .#awesome-copilot`

### Example Conventional Commit (when you commit)

```
chore(awesome-copilot): bump source rev and hash

Update to <short-sha-or-tag> and refresh fetchFromGitHub hash.
```

## Notes

- The viewer uses `mdcat` if present for nicer Markdown rendering; it falls back to `less -R` otherwise.
