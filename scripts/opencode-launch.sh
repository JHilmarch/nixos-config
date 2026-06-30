#!/usr/bin/env bash
# Launch wrapper for OpenCode under the nono sandbox.
#
# Run by the `opencode` writeShellApplication (home-modules/opencode/default.nix),
# which exports the inputs below before calling this script. It ensures opencode's
# runtime dirs exist, locks down the nono session dir, syncs Claude Max OAuth
# tokens, then execs `nono run` with the opencode profile.
#
# Inputs (exported by the Nix wrapper):
#   OC_NONO_PROFILE     path to nono-profile.jsonc
#   OC_BIN              path to the opencode binary
#   OC_TUI_PORT         loopback port to pin the TUI to (matches profile open_port)
#   OC_PERSISTENT_DIRS  newline-separated dirs to pre-create ($HOME already expanded)
#   OC_WAYLAND_CLIPBOARD  "1" to grant the Wayland compositor socket (clipboard);
#                         empty/unset to skip. See README.md "Clipboard".
#
# Behavioural notes (full rationale in home-modules/opencode/README.md):
#   - The TUI is pinned to a fixed loopback --port; subcommands pass through and a
#     user-supplied --port is respected.
#   - --allow-cwd skips nono's redundant share-cwd prompt (the dir is already
#     granted by the profile).

set -euo pipefail

# Pre-create runtime dirs (the nono profile grants the access; just create them).
while IFS= read -r dir; do
  [ -n "$dir" ] && mkdir -p "$dir" 2>/dev/null || true
done <<EOF
${OC_PERSISTENT_DIRS:-}
$HOME/.local/share/opencode/tmp
$HOME/.local/state/opencode
EOF

# nono refuses to start unless its session dir is private (mode 700).
mkdir -p "$HOME/.nono/sessions" 2>/dev/null || true
chmod 700 "$HOME/.nono" "$HOME/.nono/sessions" 2>/dev/null || true

# Sync Claude Max OAuth tokens → auth.json (idempotent, best-effort).
opencode-anthropic-auth-sync 2>/dev/null || true

# Wayland clipboard: grant connect() to the compositor socket so wl-clipboard
# can reach the host clipboard. Opt-in per host (OC_WAYLAND_CLIPBOARD=1) and
# guarded by a runtime existence check, so launching from a non-Wayland session
# (TTY/SSH/X11) silently skips the grant. See README.md "Clipboard".
oc_wayland_args=()
if [ "${OC_WAYLAND_CLIPBOARD:-}" = "1" ] &&
  [ -n "${WAYLAND_DISPLAY:-}" ] && [ -n "${XDG_RUNTIME_DIR:-}" ]; then
  case "$WAYLAND_DISPLAY" in
    /*) wl_socket="$WAYLAND_DISPLAY" ;;
    *) wl_socket="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ;;
  esac
  if [ -S "$wl_socket" ]; then
    oc_wayland_args=(--allow-unix-socket "$wl_socket")
  fi
fi

# Pin the TUI's loopback port; leave subcommands and user --port untouched.
oc_port_args=()
case "${1:-}" in
  completion | acp | mcp | attach | run | debug | providers | auth | agent | \
    upgrade | uninstall | serve | web | models | stats | export | import | \
    github | pr | session | plugin | plug | db | -v | --version | -h | --help)
    : ;;
  *)
    case " $* " in
      *" --port "* | *" --port="*) : ;;
      *) oc_port_args=(--port "$OC_TUI_PORT") ;;
    esac
    ;;
esac

exec nono run --allow-cwd "${oc_wayland_args[@]}" --profile "$OC_NONO_PROFILE" -- "$OC_BIN" "${oc_port_args[@]}" "$@"
