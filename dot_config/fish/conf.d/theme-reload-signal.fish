# Re-source lmtt colors on SIGUSR1 (sent by lmtt after theme switch)
function __lmtt_reload_colors --on-signal USR1
    if test -f ~/.config/fish/conf.d/lmtt-colors.fish
        source ~/.config/fish/conf.d/lmtt-colors.fish
    end
end
