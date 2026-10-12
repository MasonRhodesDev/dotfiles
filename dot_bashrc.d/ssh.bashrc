# SSH agent: the systemd user unit ssh-agent.socket owns the agent at
# $XDG_RUNTIME_DIR/ssh-agent.socket (the path environment.d/ssh-agent.conf
# and uwsm/env already export). Login shells that skip environment.d, such
# as Tailscale SSH, point at that socket instead of spawning their own agent.
# Only a recovery shell with no socket at all gets a throwaway agent, and it
# is killed when the shell exits, because an orphan agent pins the logind
# session in "closing" forever.
if [ ! -S "${SSH_AUTH_SOCK-}" ]; then
  _sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"
  if [ -S "$_sock" ]; then
    export SSH_AUTH_SOCK="$_sock"
  else
    eval "$(ssh-agent -s)" > /dev/null 2>&1
    trap 'ssh-agent -k > /dev/null 2>&1' EXIT
  fi
  unset _sock
fi
ssh-add -l > /dev/null 2>&1 || ssh-add ~/.ssh/id_ed25519 > /dev/null 2>&1
