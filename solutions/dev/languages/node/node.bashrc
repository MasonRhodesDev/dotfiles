export FNM_DIR="$HOME/.local/share/fnm"
path_prepend "$FNM_DIR/aliases/default/bin"
_fnm=$(type -P fnm)
if [ -z "$_fnm" ]; then
    for _fnm_dir in "$HOME/.local/share/fnm" "$HOME/.cargo/bin"; do
        if [ -x "$_fnm_dir/fnm" ]; then
            path_prepend "$_fnm_dir"
            _fnm="$_fnm_dir/fnm"
            break
        fi
    done
fi
if [ -n "$_fnm" ] && [[ $- == *i* && -z ${CLAUDECODE-} ]]; then
    eval "$("$_fnm" env --use-on-cd --version-file-strategy=recursive --shell bash)"
elif [ -n "$_fnm" ]; then
    fnm() {
        local bin
        bin=$(type -P fnm) || { echo "fnm: binary not found" >&2; return 127; }
        if [ -z "${FNM_MULTISHELL_PATH-}" ]; then
            eval "$("$bin" env)"
        fi
        "$bin" "$@"
    }
fi
unset _fnm _fnm_dir

export PNPM_HOME="$HOME/.local/share/pnpm"
path_prepend "$PNPM_HOME"
