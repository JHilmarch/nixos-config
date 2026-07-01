runHook preInstall

# Install the whole prebuilt bundle (launcher + vendored node ELF + lib tree)
# together; the launcher resolves paths relative to its own dir, so the tree
# must stay intact.
mkdir -p "$out/lib/codegraph" "$out/bin"
cp -r ./* "$out/lib/codegraph/"
chmod +x "$out/lib/codegraph/bin/codegraph" "$out/lib/codegraph/node"

# Symlink onto PATH. The launcher resolves symlinks to find the real bundle
# dir, so a makeWrapper symlink works without breaking the relative node/lib
# lookups.
makeWrapper "$out/lib/codegraph/bin/codegraph" "$out/bin/codegraph"

runHook postInstall
