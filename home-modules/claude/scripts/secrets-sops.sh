#!/bin/sh

# Load SOPS secrets for Claude Code
#
# This script sources the SOPS-rendered environment file containing API tokens
# for Claude Code and related services (Anthropic, Context7).
#
# Usage: secrets-sops.sh <path-to-claude.env>

# shellcheck disable=SC1090

CLAUDE_ENV="$1"

if [ -z "$CLAUDE_ENV" ]; then
  echo "Error: Claude env path not provided" >&2
  echo "Usage: secrets-sops.sh <path-to-claude.env>" >&2
  exit 1
fi

if [ ! -f "$CLAUDE_ENV" ]; then
  echo "Error: Claude env file not found: $CLAUDE_ENV" >&2
  exit 1
fi

. "$CLAUDE_ENV"

export ANTHROPIC_AUTH_TOKEN
export CONTEXT7_TOKEN
