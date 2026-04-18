#!/bin/sh

# Source a SOPS-rendered env file and export all defined variables.
#
# Usage: secrets-sops.sh <path-to-env-file>

# shellcheck disable=SC1090

ENV_FILE="$1"

if [ -z "$ENV_FILE" ]; then
  echo "Error: env file path not provided" >&2
  echo "Usage: secrets-sops.sh <path-to-env-file>" >&2
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: env file not found: $ENV_FILE" >&2
  exit 1
fi

set -a
. "$ENV_FILE"
set +a
