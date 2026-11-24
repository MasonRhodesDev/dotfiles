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
