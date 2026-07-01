# Body of the `oc-audit-verify` fish function (home-modules/opencode/default.nix
# reads this via builtins.readFile into programs.fish.functions).
#
# `nono audit verify` requires a <SESSION_ID>; verify the given session, or the
# latest opencode session when called with no argument. See nono-audit.md.
set -l session $argv[1]
if test -z "$session"
    set session (nono audit list --command opencode --recent 1 --json | jq -r '.[0].session_id')
    if test -z "$session" -o "$session" = null
        echo "oc-audit-verify: no opencode audit sessions found" >&2
        return 1
    end
end
nono audit verify $session
