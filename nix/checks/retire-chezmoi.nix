{ pkgs, evalHome }:
let
  program = import ../modules/home/retire-chezmoi.nix { inherit pkgs; };
  step = pkgs.writeText "retire-chezmoi-step" (evalHome { modules = [ ]; }).config.home.activation.retireChezmoi.data;
in
pkgs.runCommand "check-retire-chezmoi" { nativeBuildInputs = [ pkgs.git pkgs.gnugrep pkgs.coreutils ]; } ''
  export GIT_AUTHOR_NAME=Fixture GIT_AUTHOR_EMAIL=fixture@example.invalid GIT_COMMITTER_NAME=Fixture GIT_COMMITTER_EMAIL=fixture@example.invalid
  export GIT_CONFIG_GLOBAL=$TMPDIR/gitconfig GIT_CONFIG_NOSYSTEM=1
  git config --global init.defaultBranch main
  failures=0
  fail() { echo "FAIL $1"; echo "$said"; failures=$((failures + 1)); }

  grep -qF "run ${program}" ${step} || { echo "FAIL the activation step runs the program under run, so a dry run changes nothing"; failures=$((failures + 1)); }

  fresh() {
    export HOME=$TMPDIR/home-$1
    unset XDG_STATE_HOME XDG_DATA_HOME XDG_CONFIG_HOME XDG_CACHE_HOME
    src=$HOME/.local/share/chezmoi marker=$HOME/.local/state/dotfiles/chezmoi-state-retired
    mkdir -p "$HOME/.config/chezmoi" "$HOME/.cache/chezmoi" "$HOME/.local/state/chezmoi-drift" "$HOME/.local/state/chezmoi-installs"
    echo state > "$HOME/.config/chezmoi/chezmoistate.boltdb"
    echo data > "$HOME/.config/chezmoi/chezmoi.toml"
  }
  pushed() {
    git init -q --bare "$TMPDIR/remote-$1.git"
    git init -q "$src"
    echo tracked > "$src/dot_bashrc"
    printf '__pycache__/\n' > "$src/.gitignore"
    git -C "$src" add -A && git -C "$src" commit -qm one
    git -C "$src" remote add origin "$TMPDIR/remote-$1.git"
    git -C "$src" push -q origin main 2>/dev/null
    git -C "$src" fetch -q origin
  }
  retire() { said=$(${program} 2>&1); }
  state_gone() { [ ! -e "$HOME/.config/chezmoi" ] && [ ! -e "$HOME/.cache/chezmoi" ] && [ ! -e "$HOME/.local/state/chezmoi-drift" ] && [ ! -e "$HOME/.local/state/chezmoi-installs" ]; }
  state_kept() { [ -e "$HOME/.config/chezmoi/chezmoistate.boltdb" ] && [ -e "$HOME/.config/chezmoi/chezmoi.toml" ] && [ -e "$HOME/.cache/chezmoi" ]; }
  kept() {
    retire || fail "$1: the step does not fail the switch"
    [ -e "$src/dot_bashrc" ] || [ -e "$src/notes" ] || [ -e "$src/nix/flake.nix" ] || fail "$1: the checkout is kept"
    state_kept || fail "$1: chezmoi's state is kept while its checkout is"
    [ ! -e "$marker" ] || fail "$1: nothing is marked done, so the next switch tries again"
    grep -qF "kept $src because $2" <<< "$said" || fail "$1: the warning names the checkout and why"
  }

  fresh clean
  pushed clean
  mkdir -p "$src/scripts/__pycache__" && echo x > "$src/scripts/__pycache__/a.cpython-313.pyc"
  retire || fail "a clean checkout does not fail the switch"
  [ ! -e "$src" ] || fail "a clean checkout whose commits are all on a remote is removed"
  state_gone || fail "chezmoi's config, state database, cache and drift state go with it"
  [ -e "$marker" ] || fail "a full retirement is marked done"
  [ -e "$TMPDIR/remote-clean.git/HEAD" ] || fail "the remote is untouched"
  retire && [ -z "$said" ] || fail "a second run does nothing and says nothing"
  mkdir -p "$src" && echo later > "$src/later"
  retire && [ -e "$src/later" ] || fail "once marked done, a later chezmoi checkout is left alone"

  fresh none
  rm -rf "$HOME/.config/chezmoi"
  retire || fail "a home without chezmoi does not fail the switch"
  [ -e "$marker" ] && state_gone || fail "a home with no checkout retires what is left and is marked done"

  fresh dirty
  pushed dirty
  echo edited >> "$src/dot_bashrc"
  kept "an uncommitted change" "it has uncommitted, untracked or ignored files"
  [ "$(tail -n 1 "$src/dot_bashrc")" = edited ] || fail "the uncommitted change is still there"

  fresh untracked
  pushed untracked
  echo note > "$src/notes"
  kept "an untracked file" "it has uncommitted, untracked or ignored files"

  fresh ignored
  pushed ignored
  printf '__pycache__/\nCURRENT_PLAN.md\n' > "$src/.gitignore" && git -C "$src" commit -qam ignore && git -C "$src" push -q origin main 2>/dev/null
  echo plan > "$src/CURRENT_PLAN.md"
  kept "an ignored file" "it has uncommitted, untracked or ignored files"

  fresh unpushed
  pushed unpushed
  echo two >> "$src/dot_bashrc" && git -C "$src" commit -qam two
  kept "a commit on no remote" "it has commits that are on no remote"

  fresh detached
  pushed detached
  git -C "$src" checkout -q --detach && echo three >> "$src/dot_bashrc" && git -C "$src" commit -qam three
  kept "a commit on a detached HEAD" "it has commits that are on no remote"

  fresh noremote
  git init -q "$src" && echo tracked > "$src/dot_bashrc" && git -C "$src" add -A && git -C "$src" commit -qm one
  kept "a checkout with no remote" "it has commits that are on no remote"

  fresh stash
  pushed stash
  echo stashed >> "$src/dot_bashrc" && git -C "$src" stash -q
  kept "a stash" "it has stashed changes"

  fresh worktree
  pushed worktree
  git -C "$src" worktree add -q "$TMPDIR/linked" -b linked 2>/dev/null && git -C "$src" push -q origin linked 2>/dev/null && git -C "$src" fetch -q origin
  kept "a linked worktree" "it has linked worktrees"

  fresh plain
  mkdir -p "$src" && echo tracked > "$src/dot_bashrc"
  kept "a directory that is not a git checkout" "it is not a git checkout"

  fresh flake
  pushed flake
  mkdir -p "$src/nix" && echo "{ }" > "$src/nix/flake.nix" && git -C "$src" add -A && git -C "$src" commit -qm flake && git -C "$src" push -q origin main 2>/dev/null && git -C "$src" fetch -q origin
  kept "a checkout that holds the flake" "it holds a dotfiles flake"

  fresh first
  pushed first
  mkdir -p "$HOME/.local/state/dotfiles" && : > "$HOME/.local/state/dotfiles/first-switch"
  retire || fail "a first switch does not fail"
  [ -e "$src/dot_bashrc" ] && state_kept && [ ! -e "$marker" ] && [ -z "$said" ] \
    || fail "during a first switch, which can still be undone, chezmoi's state stays for dot to read"
  rm "$HOME/.local/state/dotfiles/first-switch"
  retire && [ ! -e "$src" ] && [ -e "$marker" ] || fail "the switch after the first one retires it"

  fresh xdg
  export XDG_DATA_HOME=$HOME/data XDG_STATE_HOME=$HOME/state XDG_CONFIG_HOME=$HOME/config XDG_CACHE_HOME=$HOME/cache
  src=$XDG_DATA_HOME/chezmoi
  mkdir -p "$XDG_CONFIG_HOME/chezmoi"
  pushed xdg
  retire && [ ! -e "$src" ] && [ ! -e "$XDG_CONFIG_HOME/chezmoi" ] && [ -e "$XDG_STATE_HOME/dotfiles/chezmoi-state-retired" ] \
    || fail "the XDG base directories are honoured"

  [ "$failures" = 0 ]
  touch $out
''
