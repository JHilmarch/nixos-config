source $__fish_config_dir/conf.d/base-shell-init.fish

if test -n "$XDG_RUNTIME_DIR"
    set -gx DOCKER_HOST "unix://$XDG_RUNTIME_DIR/docker.sock"
end

if test -f /run/secrets/gh_personal_pat
    set -gx GH_TOKEN (string trim (cat /run/secrets/gh_personal_pat))
    set -gx GITHUB_TOKEN $GH_TOKEN
end
