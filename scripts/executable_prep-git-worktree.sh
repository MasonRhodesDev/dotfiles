#!/bin/bash

REPOS_DIR="$HOME/repos"

# use git rev-parse to check if we are in a git repo
# if not, exit
if [ -z `git rev-parse --git-dir` ]; then
    echo "Not in a git repo"
    exit
fi

REMOTE_BASE=$(basename -s .git `git config --get remote.origin.url`)

# check if we are in $REPOS_DIR/$REMOTE_BASE
if [ "$PWD" == "$REPOS_DIR/$REMOTE_BASE" ]; then
    echo "Already in $REPOS_DIR/$REMOTE_BASE"
    exit
fi

# use git to find files ignored by git and add them to the list of files to be copied
# if there are any, exit
IGNORED_FILES=$(git -C "$REPOS_DIR/$REMOTE_BASE" ls-files --others --ignored --exclude-standard)
# remove anything in node_modules
IGNORED_FILES=$(echo "$IGNORED_FILES" | grep -v node_modules | grep -v .git | grep -v .vscode | grep -v .log | grep -v .jpg | grep -v .husky)


if [ -z "$IGNORED_FILES" ]; then
    echo "No local only files to move"
    exit
fi

# get the git root
GIT_ROOT=$(git rev-parse --show-toplevel)

# copy the files
for file in $IGNORED_FILES; do
    echo "copying $file"
    cp "$REPOS_DIR/$REMOTE_BASE/$file" "$GIT_ROOT/$file"
done

# Find all pacakge.json files in the repo and run npm install
PACKAGE_JSON_FILES=$(find "$GIT_ROOT" -name package.json)
if [ -z "$PACKAGE_JSON_FILES" ]; then
    echo "No package.json files to install"
    exit
fi

# install the packages
for package_json in $PACKAGE_JSON_FILES; do
    echo "Installing packages in $package_json"
    npm install --prefix $(dirname $package_json)
done
