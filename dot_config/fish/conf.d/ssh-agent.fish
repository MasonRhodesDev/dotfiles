# SSH agent setup
if not set -q SSH_AUTH_SOCK
    eval (ssh-agent -c) > /dev/null 2>&1
    ssh-add ~/.ssh/id_ed25519 > /dev/null 2>&1
end
