#!/bin/bash

# This script will reset the lifemd hotfixes branches to the latest commit on the main branch via a force push.
# This script should be run from the root of the lifemd repository.

# Exit immediately if a command exits with a non-zero status.
set -e

# Exit immediately if an uninitialized variable is used.
set -u

# Exit immediately if any command in a pipeline fails.
set -o pipefail

# Check remote repository name is thecvlb/lifemd
if [[ $(git remote get-url origin) != *"thecvlb/lifemd"* ]]; then
    echo "Remote repository is not thecvlb/lifemd"
    exit 1
fi

# Check current branch is main
if [[ $(git branch --show-current) != "main" ]]; then
    # if not main, check if branch is clean
    if [[ $(git status --porcelain) ]]; then
        echo "Current branch is not main and has uncommitted changes. Commit or stash changes and try again."
        exit 1
    fi
    # if not main and clean, checkout main
    git checkout main
else 
    # if main, check if branch is clean
    if [[ $(git status --porcelain) ]]; then
        echo "Current branch is main and has uncommitted changes. Commit or stash changes and try again."
        exit 1
    fi
fi

# get latest commits from remote
git fetch && git pull --rebase

# ask user which hotfixes branch to reset [ hotfixes | lifemd-hotfixes ]
echo "Which hotfixes branches do you want to reset?"
echo "1. hotfixes"
echo "2. lifemd-hotfixes"
read -p "Enter 1 or 2. Any other input will exit: " hotfixes_branches
echo; 

# check user input
if [[ $hotfixes_branches == "1" ]]; then
    hotfixes_branch="hotfixes"
elif [[ $hotfixes_branches == "2" ]]; then
    hotfixes_branch="lifemd-hotfixes"
else
    echo "Exiting."
    exit 1
fi

# remove local hotfixes branch if it exists
if [[ $(git branch --list $hotfixes_branch) ]]; then
    git branch -D $hotfixes_branch
fi

# create new local hotfixes branch from origin/main
git checkout -b $hotfixes_branch origin/main

# set upstream to origin/$hotfixes_branch and force push
git push --set-upstream origin $hotfixes_branch --force
