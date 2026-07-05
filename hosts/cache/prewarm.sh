# flake, key_file and hosts are provided by prewarm.nix.

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
