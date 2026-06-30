#!/bin/bash
# Third-party DNF repositories backing tracked packages, so a fresh Fedora
# machine can actually install them. Idempotent; Fedora-only.
#
# Included (backs a kept tool): hashicorp (terraform/packer), vivaldi (browser),
# acli (Atlassian CLI), hardware:razer (OpenRazer), google-chrome, slack, pritunl.
# Deliberately SKIPPED: warpdotdev.repo, vscode.repo — alternate tools not in
# packages.toml. Add them here if you decide to keep them.
# NOTE: hardware:razer pins Fedora_42 in its URL — bump on a Fedora upgrade.
set -euo pipefail

. /etc/os-release 2>/dev/null || true
case " ${ID:-} ${ID_LIKE:-} " in
    *" fedora "*) : ;;
    *) echo "Not Fedora — skipping third-party repos"; exit 0 ;;
esac

put() { # $1=filename ; rest=content
    local f="/etc/yum.repos.d/$1"; shift; local c="$*"
    if [ -f "$f" ] && [ "$(cat "$f")" = "$c" ]; then return 0; fi
    printf '%s\n' "$c" | sudo tee "$f" >/dev/null
    echo "  + $f"
}

put hashicorp.repo '[hashicorp]
name=Hashicorp Stable - $basearch
baseurl=https://rpm.releases.hashicorp.com/fedora/$releasever/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://rpm.releases.hashicorp.com/gpg'

put vivaldi.repo '[vivaldi]
name=vivaldi
baseurl=https://repo.vivaldi.com/archive/rpm/x86_64
enabled=1
gpgcheck=1
gpgkey=https://repo.vivaldi.com/archive/linux_signing_key.pub'

put acli.repo '[acli]
name=Atlassian CLI packages
baseurl=https://acli.atlassian.com/linux/rpm/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://acli.atlassian.com/gpg/public-key-rpm.asc'

put hardware:razer.repo '[hardware_razer]
name=hardware:razer (Fedora_42)
type=rpm-md
baseurl=https://download.opensuse.org/repositories/hardware:/razer/Fedora_42/
gpgcheck=1
gpgkey=https://download.opensuse.org/repositories/hardware:/razer/Fedora_42/repodata/repomd.xml.key
enabled=1'

put google-chrome.repo '[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub'

put slack.repo '[slack]
name=slack
baseurl=https://packagecloud.io/slacktechnologies/slack/fedora/21/x86_64
enabled=1
gpgcheck=0
gpgkey=https://packagecloud.io/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt'

put pritunl.repo '[pritunl]
name=Pritunl Stable Repository
baseurl=https://repo.pritunl.com/stable/yum/fedora/42/
gpgcheck=1
enabled=1'

echo "✓ third-party repos ensured (skipped: warpdotdev, vscode)"
