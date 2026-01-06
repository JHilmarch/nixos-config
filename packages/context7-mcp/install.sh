#!/bin/sh
mkdir -p $out/bin
# dist/ is in packages/mcp/dist/
cp -r * $out/

if [ -z "$CLIENT_IP_ENCRYPTION_KEY" ]; then
  CLIENT_IP_ENCRYPTION_KEY="$(openssl rand -base64 32)"
fi

# Create wrapper script with token support
cat > $out/bin/context7-mcp << EOF
#!/bin/sh
if [ -n "$CONTEXT7_TOKEN_FILE" ] && [ -f "$CONTEXT7_TOKEN_FILE" ]; then
  CONTEXT7_TOKEN="\$(cat "$CONTEXT7_TOKEN_FILE")"
fi

export CLIENT_IP_ENCRYPTION_KEY="$CLIENT_IP_ENCRYPTION_KEY"

if [ -n "$CONTEXT7_TOKEN" ]; then
  exec node "$out/packages/mcp/dist/index.js" --transport stdio --api-key "\$CONTEXT7_TOKEN" "\$@"
else
  exec node "$out/packages/mcp/dist/index.js" --transport stdio "\$@"
fi
EOF

chmod +x $out/bin/context7-mcp
