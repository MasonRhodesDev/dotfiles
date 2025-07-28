#!/bin/bash

set -e
set -o pipefail

cd $HOME/repos/lifemd

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

# if hotfix-lifemd branch exists, delete it
if [[ $(git branch --list hotfixes-lifemd) ]]; then
  git branch -D hotfixes-lifemd
fi

# create new hotfix branch
git checkout -b hotfixes

# reset hotfix to latest main
git push -u origin hotfixes --force

git checkout main

# create new hotfix-lifemd branch
git checkout -b hotfixes-lifemd

# reset hotfix-lifemd to latest main
git push -u origin hotfixes-lifemd --force
