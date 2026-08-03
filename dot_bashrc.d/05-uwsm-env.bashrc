# uwsm session env — plain `export K=V` lines, so bash sources it directly
# (fish needed a line parser for this).
[ -f "$HOME/.config/uwsm/env" ] && . "$HOME/.config/uwsm/env"
