path_remove() {
    local dir=$1 result= entry
    local IFS=:
    for entry in $PATH; do
        [ "$entry" = "$dir" ] && continue
        result="${result:+$result:}$entry"
    done
    PATH=$result
}

path_prepend() {
    [ -d "$1" ] || return 0
    path_remove "$1"
    PATH="$1${PATH:+:$PATH}"
    export PATH
}

path_append() {
    [ -d "$1" ] || return 0
    path_remove "$1"
    PATH="${PATH:+$PATH:}$1"
    export PATH
}

path_dedupe() {
    local result= entry seen_fnm=0
    local IFS=:
    for entry in $PATH; do
        [ -n "$entry" ] || continue
        [ -d "$entry" ] || continue
        case $entry in
            */fnm_multishells/*)
                [ "$seen_fnm" -eq 1 ] && continue
                seen_fnm=1
                ;;
        esac
        case ":$result:" in
            *":$entry:"*) continue ;;
        esac
        result="${result:+$result:}$entry"
    done
    PATH=$result
    export PATH
}
