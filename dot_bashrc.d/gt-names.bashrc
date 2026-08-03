# Dynamic name completion for `gt` (rig + crew names) — port of the retired
# fish completions/gt_names.fish. gt's Cobra completion implements no
# ValidArgsFunction for these name args, so they are supplied here.
#
# Bash allows exactly ONE completion spec per command (fish stacked several),
# so this eager-loads the generated cobra script and registers a wrapper that
# serves the name positions itself and delegates everything else to cobra's
# __start_gt. Registering at shell start also preempts bash-completion's lazy
# loader, so regenerating the cobra file needs no re-append.

if [ -f "$HOME/.local/share/bash-completion/completions/gt" ]; then
    . "$HOME/.local/share/bash-completion/completions/gt"

    __gt_rigs() {
        local f
        for f in /home/mason/agent-town/town/*/config.json; do
            [ -f "$f" ] && basename "$(dirname "$f")"
        done
    }

    __gt_crews() {
        local d
        for d in /home/mason/agent-town/town/*/crew/*/; do
            [ -d "$d" ] && basename "$d"
        done
    }

    _gt_with_names() {
        local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]-}
        local sub=${COMP_WORDS[1]-}

        # `--rig <rig>` flag value (e.g. gt crew add x --rig <rig>)
        if [[ $prev == --rig ]]; then
            COMPREPLY=($(compgen -W "$(__gt_rigs)" -- "$cur"))
            return
        fi

        # `gt <subcmd> <rig>` for top-level subcommands taking a rig positional
        if [[ $COMP_CWORD -eq 2 ]]; then
            case $sub in
            boot|start|stop|status|reboot|restart|park|unpark|shutdown|reset|settings|config)
                COMPREPLY=($(compgen -W "$(__gt_rigs)" -- "$cur"))
                return ;;
            esac
        fi

        if [[ $COMP_CWORD -eq 3 ]]; then
            # `gt sling <bead> <rig>` — rig is the 2nd positional
            if [[ $sub == sling ]]; then
                COMPREPLY=($(compgen -W "$(__gt_rigs)" -- "$cur"))
                return
            fi
            # `gt crew <at|start|stop|remove|refresh|restart|rename> <crew>`
            if [[ $sub == crew ]]; then
                case ${COMP_WORDS[2]-} in
                at|start|stop|remove|refresh|restart|rename)
                    COMPREPLY=($(compgen -W "$(__gt_crews)" -- "$cur"))
                    return ;;
                esac
            fi
        fi

        __start_gt
    }

    complete -o default -F _gt_with_names gt
fi
