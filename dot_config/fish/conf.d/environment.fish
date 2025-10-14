# Source shared POSIX environment variables
if test -f ~/.config/environment
    # Parse and export variables from POSIX format
    for line in (cat ~/.config/environment | grep -v '^#' | grep -v '^$' | grep 'export')
        set -l clean_line (string replace 'export ' '' $line)
        set -l parts (string split -m 1 '=' $clean_line)
        if test (count $parts) -eq 2
            # Remove quotes if present
            set -l value (string trim -c '"' $parts[2])
            # Expand $HOME and other variables
            set -l expanded_value (string replace -a '$HOME' $HOME $value)
            set -l expanded_value (string replace -a '$PATH' $PATH $expanded_value)
            set -gx $parts[1] $expanded_value
        end
    end
end
