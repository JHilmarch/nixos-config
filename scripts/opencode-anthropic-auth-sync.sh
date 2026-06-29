#!/usr/bin/env bash
# Sync Claude Code's OAuth tokens into OpenCode's auth.json so the
# @ex-machina/opencode-anthropic-auth plugin can authenticate `anthropic/*` requests
# against the Claude Code Max subscription.
#
# Source : ~/.claude/.credentials.json   (populated by `claude auth login`)
# Target : ~/.local/share/opencode/auth.json   (read by the plugin)
#
# Idempotent. Safe to run on every OpenCode startup. Skips cleanly when source
# tokens are missing or malformed. Does NOT clobber other providers in auth.json.

set -euo pipefail

CLAUDE_CRED="${HOME}/.claude/.credentials.json"
OPENCODE_AUTH="${HOME}/.local/share/opencode/auth.json"

log() { printf 'opencode-anthropic-auth-sync: %s\n' "$*" >&2; }

# Skip if Claude Code hasn't been authenticated
if [ ! -f "$CLAUDE_CRED" ]; then
  log "SKIP — $CLAUDE_CRED not found (run 'claude auth login' first)"
  exit 0
fi

# Skip if the OAuth entry is incomplete
if ! jq -e '.claudeAiOauth | has("accessToken") and has("refreshToken") and has("expiresAt")' "$CLAUDE_CRED" > /dev/null 2>&1; then
  log "SKIP — no valid claudeAiOauth entry in $CLAUDE_CRED"
  exit 0
fi

# Ensure target exists
mkdir -p "$(dirname "$OPENCODE_AUTH")"
touch "$OPENCODE_AUTH"

# If auth.json is empty/invalid, seed with {}
if ! jq -e '.' "$OPENCODE_AUTH" > /dev/null 2>&1; then
  echo '{}' > "$OPENCODE_AUTH"
fi

# Build the anthropic entry in the plugin's expected format
NEW_ENTRY=$(jq '{
  type: "oauth",
  access: .claudeAiOauth.accessToken,
  refresh: .claudeAiOauth.refreshToken,
  expires: .claudeAiOauth.expiresAt
}' "$CLAUDE_CRED")

# Skip if the existing entry is already identical (avoid touching mtimes on every startup)
EXISTING=$(jq -c '.anthropic // empty' "$OPENCODE_AUTH" 2>/dev/null || echo '')
NEW_COMPACT=$(echo "$NEW_ENTRY" | jq -c '.')
if [ "$EXISTING" = "$NEW_COMPACT" ]; then
  log "SKIP — auth.json anthropic entry already up to date"
  exit 0
fi

# Merge: write a tmp file then atomically move (never leave auth.json half-written)
jq --argjson entry "$NEW_ENTRY" '.anthropic = $entry' "$OPENCODE_AUTH" > "$OPENCODE_AUTH.tmp"
mv "$OPENCODE_AUTH.tmp" "$OPENCODE_AUTH"

EXPIRES_ISO=$(jq -r '.anthropic.expires' "$OPENCODE_AUTH" | xargs -I{} date -d @{} -Ins 2>/dev/null || echo '?')
log "synced anthropic OAuth tokens (expires: $EXPIRES_ISO)"
