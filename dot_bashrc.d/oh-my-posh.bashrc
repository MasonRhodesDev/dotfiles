# Initialize oh-my-posh with local theme
if command -v oh-my-posh &> /dev/null; then
    # Use local theme file if it exists, otherwise use default theme
    OMP_THEME="$HOME/.config/oh-my-posh/themes/custom.omp.json"
    if [ -f "$OMP_THEME" ]; then
        eval "$(oh-my-posh init bash --config "$OMP_THEME")"
    else
        eval "$(oh-my-posh init bash)"
    fi
fi
