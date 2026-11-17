__infisical_env_file=$HOME/.config/infisical/env.sh
export BASH_ENV=$__infisical_env_file

__infisical_env_reload() {
    local f=$__infisical_env_file stamp k old
    [ -r "$f" ] || return 0
    stamp=$(stat -c %Y.%s "$f" 2>/dev/null) || return 0
    [ "$stamp" = "${__infisical_env_stamp-}" ] && return 0
    old=" ${__INFISICAL_KEYS-} "
    . "$f"
    for k in $old; do
        case " $__INFISICAL_KEYS " in *" $k "*) ;; *) unset "$k" ;; esac
    done
    __infisical_env_stamp=$stamp
}

__infisical_env_reload
case ";${PROMPT_COMMAND-};" in
    *";__infisical_env_reload;"*) ;;
    *) PROMPT_COMMAND="__infisical_env_reload${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
esac
