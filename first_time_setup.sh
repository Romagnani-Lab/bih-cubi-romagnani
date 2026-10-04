#!/bin/bash
# One-time account setup for the BIH HPC. Safe to re-run.
# Usage: bash first_time_setup.sh

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin_dir="$HOME/work/bin"
pixi_home="$bin_dir/pixi_bin"
mkdir -p "$bin_dir"

# Pick up a pixi installed on an earlier run, even if .bashrc wasn't re-sourced.
export PATH="$pixi_home/bin:$PATH"

err()  { echo -e "\033[0;31mERROR:\033[0m $*" >&2; }
warn() { echo -e "\033[0;33mWARNING:\033[0m $*" >&2; }

# Returns 1 on "n" or when there's no input (EOF), so non-interactive runs skip everything.
ask() {
    local reply
    while read -rn 1 -p "$1 (y/n): " reply; do
        echo
        case "$reply" in
            [Yy]) return 0 ;;
            [Nn]) return 1 ;;
        esac
    done
    return 1
}

add_to_bashrc() {
    grep -qxF "$1" "$HOME/.bashrc" 2>/dev/null || printf '\n%s\n' "$1" >> "$HOME/.bashrc"
}

# Move ~/<name> into ~/work/bin/<name> and leave a symlink, keeping it off the 1 GB home quota.
link_to_work() {
    local home_path="$HOME/$1" work_path="$bin_dir/$1"
    mkdir -p "$work_path"
    if [ -L "$home_path" ]; then
        ln -sfn "$work_path" "$home_path"
    elif [ -d "$home_path" ]; then
        # Copy then delete: home and work are separate mounts, and an interrupted mv can lose data.
        cp -a "$home_path/." "$work_path/" && rm -rf "$home_path" && ln -s "$work_path" "$home_path" \
            || err "Could not move $home_path to $work_path; left in place."
    elif [ -e "$home_path" ]; then
        err "$home_path is a file, not a directory; skipped."
    else
        ln -s "$work_path" "$home_path"
    fi
}

create_symlinks() {
    local name
    for name in .cache .config .ipython .jupyter .local .ncbi .nv .nextflow ondemand .parallel; do
        link_to_work "$name"
    done

    local pair target
    for pair in "/data/cephfs-2/unmirrored/groups/romagnani:group" \
                "/data/cephfs-2/unmirrored/projects/romagnani-share:share"; do
        target="${pair%:*}" name="${pair##*:}"
        if [ -d "$target" ]; then
            ln -sfn "$target" "$HOME/$name"
        else
            warn "No access to $target yet; skipped ~/$name. Ask Ollie."
        fi
    done

    # Keep temp files on scratch rather than node-local /tmp. Single quotes: expanded at login, per node.
    # shellcheck disable=SC2016
    add_to_bashrc 'export TMPDIR=$HOME/scratch/tmp/$(hostname)'
    # shellcheck disable=SC2016
    add_to_bashrc 'mkdir -p "$TMPDIR"'
}

install_pixi() {
    curl -fsSL https://pixi.sh/install.sh | PIXI_HOME="$pixi_home" PIXI_NO_PATH_UPDATE=1 bash > /dev/null \
        && add_to_bashrc "export PATH=\"$pixi_home/bin:\$PATH\"" \
        && pixi --version
}

# Copies envs/pixi/<name> to ~/work/bin/pixi/<name> and installs it from the lockfile.
install_env() {
    local src="$repo_dir/envs/pixi/$1" dest="$bin_dir/pixi/$1"
    command -v pixi > /dev/null || { err "pixi not installed."; return 1; }
    mkdir -p "$dest"
    # Don't overwrite an existing env: it may have packages the user added with `pixi add`.
    if [ -f "$dest/pixi.toml" ]; then
        echo "Keeping existing $dest/pixi.toml"
    else
        cp "$src/pixi.toml" "$src/pixi.lock" "$dest/"
    fi
    echo "Installing $1 (this can take a while)..."
    pixi install --locked --manifest-path "$dest/pixi.toml" && echo "$1 ready at $dest"
}

install_ood_apps() {
    local dev_dir="$bin_dir/ondemand/dev" repo
    mkdir -p "$dev_dir"
    for repo in ood-bih-rstudio-server ood-bih-jupyter; do
        if [ -d "$dev_dir/$repo/.git" ]; then
            git -C "$dev_dir/$repo" pull --quiet || err "Could not update $repo."
        else
            git -C "$dev_dir" clone --quiet "https://github.com/Romagnani-Lab/$repo" || err "Could not clone $repo."
        fi
        # New dirs inherit setgid; OnDemand tries to copy that bit when staging and CephFS refuses (EPERM).
        if [ -d "$dev_dir/$repo" ]; then chmod -R g-s "$dev_dir/$repo"; fi
    done
}

# Steps are independent: report a failure and carry on.
step() { "$@" || err "$1 failed. Re-run the script to retry."; }

ask "Move config/cache folders out of your home directory (recommended)?" && step create_symlinks
ask "Install pixi (recommended)?"                                        && step install_pixi
ask "Install the R 4.5.0 environment for RStudio (10-20 min)?"           && step install_env R_4.5.0
ask "Install the reticulate Python environment (Python from R)?"         && step install_env r-reticulate
ask "Install the Jupyter single-cell environment (large; skip unless you use JupyterLab)?" && step install_env jupyter
ask "Install or update the RStudio and Jupyter portal apps (recommended)?" && step install_ood_apps

echo -e "\n\033[0;32mDone.\033[0m Open a new terminal (or run: source ~/.bashrc) to apply the changes."
