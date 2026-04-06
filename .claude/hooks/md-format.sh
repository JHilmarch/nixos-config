#!/usr/bin/env bash
# Format .md files with mdformat after Write/Edit
FILE_PATH=$(jq -r '.tool_input.file_path')
if [[ "$FILE_PATH" == *.md ]]; then
  mdformat "$FILE_PATH"
fi
