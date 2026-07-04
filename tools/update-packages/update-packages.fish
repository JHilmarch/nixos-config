#!/usr/bin/env fish
# @fish-lsp-disable 4004
#
# update-packages — Manage custom package versions
#
# Usage:
#   fish tools/update-packages/update-packages.fish <command> [OPTIONS]
#
# Commands:
#   list                    Show current and latest versions for all packages
#   update <pkg...>         Update one or more packages
#   update --all            Update all packages that have updates available
#
# Options:
#   --json                  Output structured JSON (no other output)
#   --help                  Show this help message
#
# Packages:
#   azure-devops-mcp       GitHub releases (microsoft/azure-devops-mcp)
#   azure-mcp-server       NuGet (Azure.Mcp)

# Fish exits on command failure by default; explicit `or return 1`/`or exit 1` used where needed

# ── Load library ──────────────────────────────────────────────────────────────

set -g JSON_MODE false
set -g REPO_ROOT

set -l script_dir (dirname (status filename))
source "$script_dir/../common/log.fish"
source "$script_dir/lib/nix.fish"
source "$script_dir/lib/nuget.fish"
source "$script_dir/lib/repo.fish"
source "$script_dir/lib/validate.fish"

# Load all package definitions
for pkg_file in "$script_dir"/packages/*.fish
    source "$pkg_file"
end

# ── Package registry ─────────────────────────────────────────────────────────

set -g ALL_PACKAGES azure-devops-mcp azure-mcp-server codegraph

# ── List command ──────────────────────────────────────────────────────────────

function cmd_list
    set -l results '[]'
    for pkg in $ALL_PACKAGES
        set -l current (current_$pkg)
        set -l latest (fetch_latest_$pkg)

        if test -z "$latest" -o "$latest" = null
            set latest unknown
        end
        if test -z "$current"
            set current unknown
        end

        set -l pkg_status up-to-date
        if test "$current" != "$latest" -a "$latest" != unknown
            set pkg_status outdated
        end

        set -l entry "{\"name\":\"$pkg\",\"current\":\"$current\",\"latest\":\"$latest\",\"status\":\"$pkg_status\"}"
        set results (echo "$results" | jq --argjson e "$entry" '. + [$e]')
    end

    if test "$JSON_MODE" = true
        echo "$results" | jq -c '.'
    else
        echo "$results" | jq -r '.[] | [.name, .current, .latest, .status] | @tsv' \
            | awk 'BEGIN{print "Package\tCurrent\tLatest\tStatus"}1' | column -t -s '	'
    end
end

# ── Update command ───────────────────────────────────────────────────────────

function cmd_update
    set -l targets $argv
    if test (count $targets) -eq 1; and test $targets[1] = --all
        set targets $ALL_PACKAGES
    end

    set -l results '[]'

    for pkg in $targets
        if not contains -- "$pkg" $ALL_PACKAGES
            log_error "Unknown package: $pkg"
            set -l entry "{\"name\":\"$pkg\",\"status\":\"error\",\"error\":\"Unknown package\"}"
            set results (echo "$results" | jq --argjson e "$entry" '. + [$e]')
            continue
        end

        set -l current (current_$pkg)
        set -l latest (fetch_latest_$pkg)

        if test -z "$latest" -o "$latest" = null
            set -l entry "{\"name\":\"$pkg\",\"status\":\"error\",\"error\":\"Failed to fetch latest version\"}"
            set results (echo "$results" | jq --argjson e "$entry" '. + [$e]')
            continue
        end

        if test "$current" = "$latest"
            set -l entry "{\"name\":\"$pkg\",\"current\":\"$current\",\"status\":\"already-up-to-date\"}"
            set results (echo "$results" | jq --argjson e "$entry" '. + [$e]')
            log_info "$pkg is already at $latest"
            continue
        end

        log_info "Updating $pkg: $current -> $latest"
        if update_$pkg $latest
            set -l entry "{\"name\":\"$pkg\",\"previous\":\"$current\",\"current\":\"$latest\",\"status\":\"updated\"}"
            set results (echo "$results" | jq --argjson e "$entry" '. + [$e]')
        else
            set -l entry "{\"name\":\"$pkg\",\"previous\":\"$current\",\"status\":\"error\",\"error\":\"Update failed\"}"
            set results (echo "$results" | jq --argjson e "$entry" '. + [$e]')
        end
    end

    if test "$JSON_MODE" = true
        echo "$results" | jq -c '.'
    else
        echo "$results" | jq -r '.[] | "\(.name)\t\(.status)\t\(.previous // "" )\(if .previous and .current then " -> " + .current else "" end)"' \
            | awk 'BEGIN{print "Package\tStatus\tChange"}1' | column -t
    end
end

# ── Main ─────────────────────────────────────────────────────────────────────

# Parse global flags (pre-scan for --json so --help respects it)
if contains -- --json $argv
    set JSON_MODE true
end
set -l cmd_args
for arg in $argv
    switch $arg
        case --json
            set JSON_MODE true
        case --help
            if test "$JSON_MODE" = true
                echo '{}' | jq '{
                    name: "update-packages",
                    description: "Manage custom package versions",
                    commands: [
                        {name: "list", description: "Show current and latest versions for all packages"},
                        {name: "update", params: ["<pkg...>"], description: "Update one or more packages"},
                        {name: "update", params: ["--all"], description: "Update all packages with updates available"}
                    ],
                    global_options: [
                        {name: "--json", description: "Output structured JSON (suppresses all other output)"},
                        {name: "--help", description: "Show this help (--help --json for machine-readable)"}
                    ]
                }'
            else
                echo "update-packages — Manage custom package versions"
                echo ""
                echo "Usage:"
                echo "  fish tools/update-packages/update-packages.fish list [--json]"
                echo "  fish tools/update-packages/update-packages.fish update <pkg...> [--json]"
                echo "  fish tools/update-packages/update-packages.fish update --all [--json]"
                echo ""
                echo "Commands:"
                echo "  list              Show current and latest versions for all packages"
                echo "  update <pkg...>   Update one or more packages"
                echo "  update --all      Update all packages that have updates available"
                echo ""
                echo "Options:"
                echo "  --json            Output structured JSON (suppresses all other output)"
                echo "  --help            Show this help message"
                echo ""
                echo "Packages:"
                for pkg in $ALL_PACKAGES
                    echo "  $pkg"
                end
            end
            exit 0
        case '*'
            set -a cmd_args $arg
    end
end

# Validate
require_cmd curl jq nix sed; or die "Missing required command."
set REPO_ROOT (find_repo_root); or die "Not in a nixos-config repository."
cd "$REPO_ROOT"

if test (count $cmd_args) -lt 1
    if test "$JSON_MODE" = true
        echo '{}' | jq '{error: "No command specified. Run with --help for usage."}'
    else
        echo "Usage: fish tools/update-packages/update-packages.fish <command> [OPTIONS]"
        echo "Run with --help for full usage."
    end
    exit 1
end

set -l command $cmd_args[1]
set -e cmd_args[1]

switch $command
    case list
        cmd_list
    case update
        if test (count $cmd_args) -lt 1
            die "update requires at least one package name or --all"
        end
        cmd_update $cmd_args
    case '*'
        die "Unknown command: $command. Run with --help for usage."
end
exit 0
