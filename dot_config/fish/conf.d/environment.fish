if test -f ~/.config/environment
    for line in (cat ~/.config/environment | grep 'export' | grep -v '^#' | grep -v '^$')
        set -l clean_line (string trim $line)
        set -l clean_line (string replace 'export ' '' $clean_line)
        set -l parts (string split -m 1 '=' $clean_line)
        if test (count $parts) -eq 2
            set -l var_name (string trim $parts[1])
            if test -n "$var_name"; and not string match -q '* *' "$var_name"
                set -l value (string trim -c '"' $parts[2])
                set -l expanded_value (string replace -a '$HOME' $HOME $value)
                set -l expanded_value (string replace -a '$PATH' $PATH $expanded_value)
                set -gx $var_name $expanded_value
            end
        end
    end
end
