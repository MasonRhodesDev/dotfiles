#!/bin/bash

set -e
set -o pipefail

cd "$HOME/repos/redacted"

# if not on main branch, checkout main
if [[ $(git branch --show-current) != "main" ]]; then
  git checkout main
fi

# pull latest main
git pull

# if hotfix branch exists, delete it
if [[ $(git branch --list hotfixes) ]]; then
  git branch -D hotfixes
fi

# if hotfix-redacted branch exists, delete it
if [[ $(git branch --list hotfixes-redacted) ]]; then
  git branch -D hotfixes-redacted
fi

# create new hotfix branch
git checkout -b hotfixes

# reset hotfix to latest main
git push -u origin hotfixes --force

git checkout main

# create new hotfix-redacted branch
git checkout -b hotfixes-redacted

# reset hotfix-redacted to latest main
git push -u origin hotfixes-redacted --force
