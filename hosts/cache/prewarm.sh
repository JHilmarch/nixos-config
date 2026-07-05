# flake, key_file and hosts are provided by prewarm.nix.

# Fail fast on a malformed signing key. A key without the "<name>:<secret>"
# shape makes every `nix store sign` fail with "key is corrupt", so abort with
# one clear error instead of silently failing to sign every host.
if [ ! -s "$key_file" ]; then
  echo "prewarm: signing key $key_file is missing or empty" >&2
  exit 1
fi
key_name=$(cut -d: -f1 < "$key_file")
key_secret=$(cut -d: -f2- < "$key_file")
if [ -z "$key_name" ] || [ -z "$key_secret" ] || [ "$key_name" = "$(cat "$key_file")" ]; then
  echo "prewarm: signing key $key_file is not in <name>:<base64> form" >&2
  exit 1
fi

failures=0
for host in "${hosts[@]}"; do
  echo "prewarm: realising toplevel for $host"
  attr="$flake#nixosConfigurations.$host.config.system.build.toplevel"

  if ! out=$(nix build --no-link --print-out-paths "$attr" 2>&1); then
    echo "prewarm: FAILED to build $host — skipping" >&2
    printf '%s\n' "$out" >&2
    failures=$((failures + 1))
    continue
  fi

  if ! nix store sign --recursive --key-file "$key_file" "$out"; then
    echo "prewarm: FAILED to sign closure for $host ($out)" >&2
    failures=$((failures + 1))
    continue
  fi

  echo "prewarm: signed $host → $out"
done

if [ "$failures" -gt 0 ]; then
  echo "prewarm: completed with $failures host failure(s)" >&2
  exit 1
fi
echo "prewarm: all hosts realised and signed"
