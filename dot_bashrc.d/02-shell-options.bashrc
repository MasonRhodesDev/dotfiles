# Interactive shell behaviour: shopt flags, small aliases, no bell.
[[ $- == *i* ]] || return 0

shopt -s autocd      # a bare directory name cds into it
shopt -s cdspell     # fix minor typos in cd arguments
shopt -s dirspell    # ... and while completing them
shopt -s globstar    # ** recurses
shopt -s checkjobs   # warn about running jobs before exiting
shopt -s no_empty_cmd_completion  # Tab on an empty line does not list every command
shopt -u sourcepath  # "source x" reads ./x, not something on PATH

# Listing aliases. eza is optional: when it is installed the ls family picks it
# up, otherwise plain coreutils with colour.
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

# A terminal bell on every failed completion is noise in kitty. ble.sh reads
# its own option (edit_abell in ~/.blerc); this covers plain readline.
bind 'set bell-style none' 2>/dev/null
