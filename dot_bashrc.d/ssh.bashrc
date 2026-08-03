# SSH agent: the systemd user unit ssh-agent.socket owns the agent at
# $XDG_RUNTIME_DIR/ssh-agent.socket (the path environment.d/ssh-agent.conf
# and uwsm/env already export). Only spawn a throwaway agent when that
# socket is missing (recovery shells), and only add the key when the agent
# holds none — never one agent per shell.
[ -S "${SSH_AUTH_SOCK-}" ] || eval "$(ssh-agent -s)" > /dev/null 2>&1
ssh-add -l > /dev/null 2>&1 || ssh-add ~/.ssh/id_ed25519 > /dev/null 2>&1
