#!/bin/sh
set -eu

# PriTunl
if ! command -v pritunl-client &> /dev/null; then
    echo "Prepping VPN"
    sudo bash -c 'cat <<EOF > /etc/yum.repos.d/pritunl.repo
[pritunl]
name=Pritunl Stable Repository
baseurl=https://repo.pritunl.com/stable/yum/fedora/39/
gpgcheck=1
enabled=1
EOF'
    
    sudo dnf install -y pritunl-client-electron
fi


exit 0
