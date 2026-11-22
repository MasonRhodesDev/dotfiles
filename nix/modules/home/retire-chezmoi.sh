#!/usr/bin/env bash
set -euo pipefail

git=@git@
state=${XDG_STATE_HOME:-$HOME/.local/state}
done_marker=$state/dotfiles/chezmoi-state-retired
source_dir=${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi
leftovers=(
  "${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi"
  "${XDG_CACHE_HOME:-$HOME/.cache}/chezmoi"
  "$state/chezmoi-drift"
  "$state/chezmoi-installs"
)

[ -e "$done_marker" ] && exit 0
[ -e "$state/dotfiles/first-switch" ] && exit 0

exists() { [ -e "$1" ] || [ -L "$1" ]; }

why_kept() {
  local dir=$1 top changes stashes unpushed trees
  if [ -e "$dir/nix/flake.nix" ]; then echo "it holds a dotfiles flake that a switch may run from"; return; fi
  if ! top=$("$git" -C "$dir" rev-parse --show-toplevel 2>/dev/null) || [ ! "$top" -ef "$dir" ]; then
    echo "it is not a git checkout, so its contents cannot be checked"; return
  fi
  changes=$("$git" -C "$dir" status --porcelain --ignored=matching --untracked-files=all 2>/dev/null) || { echo "git cannot read its status"; return; }
  changes=$(grep -v -e '__pycache__/' -e '\.pyc$' <<< "$changes" || true)
  if [ -n "$changes" ]; then echo "it has uncommitted, untracked or ignored files"; return; fi
  stashes=$("$git" -C "$dir" stash list 2>/dev/null) || { echo "git cannot read its stash"; return; }
  if [ -n "$stashes" ]; then echo "it has stashed changes"; return; fi
  unpushed=$("$git" -C "$dir" log HEAD --branches --tags --not --remotes --format=%h -n 1 2>/dev/null) || { echo "git cannot read its history"; return; }
  if [ -n "$unpushed" ]; then echo "it has commits that are on no remote"; return; fi
  trees=$("$git" -C "$dir" worktree list --porcelain 2>/dev/null) || { echo "git cannot list its worktrees"; return; }
  if [ "$(grep -c '^worktree ' <<< "$trees" || true)" -gt 1 ]; then echo "it has linked worktrees"; return; fi
}

if exists "$source_dir"; then
  if [ -L "$source_dir" ] || [ ! -d "$source_dir" ]; then
    reason="it is not a directory"
  else
    reason=$(why_kept "$source_dir")
  fi
  if [ -n "$reason" ]; then
    echo "dotfiles: kept $source_dir because $reason. Move what matters out of it, or remove it, and the next switch retires the rest of chezmoi's state." >&2
    exit 0
  fi
  rm -rf "$source_dir"
  echo "dotfiles: removed chezmoi's source checkout $source_dir. Every commit in it is on a remote."
fi

for path in "${leftovers[@]}"; do
  if exists "$path"; then
    rm -rf "$path"
    echo "dotfiles: removed chezmoi's $path"
  fi
done
mkdir -p "$(dirname "$done_marker")"
: > "$done_marker"
