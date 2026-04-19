#!/usr/bin/env bash
# Format .json/.jsonc files with biome after Write/Edit
FILE_PATH=$(jq -r '.tool_input.file_path')
if [[ "$FILE_PATH" == *.json || "$FILE_PATH" == *.jsonc ]]; then
  biome check --write "$FILE_PATH"
fi
