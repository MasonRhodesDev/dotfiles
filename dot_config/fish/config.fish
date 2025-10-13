# Vi keybindings
fish_vi_key_bindings

# Oh My Posh prompt
oh-my-posh init fish --config /home/mason/.config/oh-my-posh/bubbles.omp.json | source

# Source uwsm environment variables
if test -f ~/.config/uwsm/env
    for line in (cat ~/.config/uwsm/env | grep -v '^#' | grep -v '^$')
        set -l clean_line (string replace 'export ' '' $line)
        set -l parts (string split '=' $clean_line)
        if test (count $parts) -eq 2
            set -gx $parts[1] $parts[2]
        end
    end
end

# Editor variables (if not already set by uwsm)
set -gx EDITOR nvim
set -gx VISUAL nvim

# Add local binaries to PATH
fish_add_path ~/.local/bin
fish_add_path ~/bin
