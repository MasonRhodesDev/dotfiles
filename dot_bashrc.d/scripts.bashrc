# Scripts and PATH configuration
# Add scripts directory to PATH
if ! [[ "$PATH" =~ "$HOME/scripts:" ]]; then
    PATH="$HOME/scripts:$PATH"
fi

# Claude CLI alias
alias claude="$HOME/.claude/local/claude"