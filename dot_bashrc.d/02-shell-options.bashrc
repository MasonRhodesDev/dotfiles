[[ $- == *i* ]] || return 0

shopt -s autocd
shopt -s cdspell
shopt -s dirspell
shopt -s globstar
shopt -s checkjobs
shopt -s no_empty_cmd_completion
shopt -u sourcepath

if [[ -z ${CLAUDECODE-} ]]; then
    if command -v eza >/dev/null 2>&1; then
        alias ls='eza --group-directories-first'
        alias ll='eza -l --group-directories-first --git'
        alias la='eza -la --group-directories-first --git'
        alias lt='eza --tree --level=2 --group-directories-first'
    else
        alias ls='ls --color=auto --group-directories-first'
        alias ll='ls -l --color=auto --group-directories-first'
        alias la='ls -la --color=auto --group-directories-first'
    fi
    alias l='ll'
    alias ..='cd ..'
    alias ...='cd ../..'
    alias tree='tree -C'
    alias ip='ip -color=auto'
fi

bind 'set bell-style none' 2>/dev/null
