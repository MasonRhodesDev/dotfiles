# Source shared POSIX environment variables
if test -f ~/.config/environment
    # Parse and export variables from POSIX format
    for line in (cat ~/.config/environment | grep 'export' | grep -v '^#' | grep -v '^$')
        # Trim leading/trailing whitespace
        set -l clean_line (string trim $line)
        set -l clean_line (string replace 'export ' '' $clean_line)
        set -l parts (string split -m 1 '=' $clean_line)
        if test (count $parts) -eq 2
            set -l var_name (string trim $parts[1])
            # Skip if variable name is empty or contains spaces
            if test -n "$var_name"; and not string match -q '* *' "$var_name"
                # Remove quotes if present
                set -l value (string trim -c '"' $parts[2])
                # Expand $HOME and other variables
                set -l expanded_value (string replace -a '$HOME' $HOME $value)
                set -l expanded_value (string replace -a '$PATH' $PATH $expanded_value)
                set -gx $var_name $expanded_value
            end
        end
    end
end
