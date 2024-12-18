
### START-Keychain ###
# Let  re-use ssh-agent and/or gpg-agent between logins
if [[ $- == *i* ]]; then
	/usr/bin/keychain $HOME/.ssh/ids/lifemd_id_ed25519 --quiet --agents ssh
	source $HOME/.keychain/$HOSTNAME-sh
fi
### End-Keychain ###

