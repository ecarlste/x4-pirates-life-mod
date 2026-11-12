# shellcheck shell=bash
# deploy.config's settings for the bash tools, sourced by tools/game-lock.sh (and through it
# deploy.sh). A setting comes from the checkout's own deploy.config, else, in a linked worktree, the
# main checkout's, so worktrees need no copy. tools/diff-patches/config.ts and
# tools/deploy-config.ps1 are its TypeScript and PowerShell twins; keep the three in step.
#
#   deploy_config_main ROOT        print the main checkout of the worktree at ROOT ('' if ROOT isn't one)
#   deploy_config_files ROOT       print the deploy.config files to read, in order, one per line
#   deploy_config_value ROOT KEY   print KEY's value from the first file that sets it ('' if none)

# The main checkout, from the worktree's .git file (gitdir: <main>/.git/worktrees/<name>) and that
# folder's commondir (../..)
deploy_config_main() {
    local root=$1 gitdir common
    [ -f "$root/.git" ] || return 0
    gitdir=$(sed -n 's/^gitdir:[[:space:]]*//p' "$root/.git" | head -n 1 | sed 's/[[:space:]]*$//')
    [ -n "$gitdir" ] || return 0
    [[ "$gitdir" = /* ]] || gitdir="$root/$gitdir"
    common=$gitdir
    [ -f "$gitdir/commondir" ] && common="$gitdir/$(head -n 1 "$gitdir/commondir" | tr -d '\r')"
    common=$(cd "$common" 2>/dev/null && pwd) || return 0
    [ "$(basename "$common")" = .git ] && dirname "$common"
    return 0
}

deploy_config_files() {
    local root=$1 main
    [ -f "$root/deploy.config" ] && echo "$root/deploy.config"
    main=$(deploy_config_main "$root")
    [ -n "$main" ] && [ -f "$main/deploy.config" ] && echo "$main/deploy.config"
    return 0
}

# A KEY="value" line, read and never run: the last one in a file wins, quotes optional, and an empty
# value counts as not set
deploy_config_value() {
    local root=$1 key=$2 file value
    while read -r file; do
        value=$(sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//p" "$file" | tail -n 1 | sed 's/[[:space:]]*$//')
        value=${value#\"}; value=${value%\"}
        value=${value#\'}; value=${value%\'}
        [ -n "$value" ] || continue
        printf '%s\n' "$value"
        return 0
    done < <(deploy_config_files "$root")
}
