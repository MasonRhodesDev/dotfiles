#!/bin/bash

#  ./get-prog.sh <program name> --env=<vars> --args=<args>

app=$1

if [ -z "$app" ]; then
    echo "No program name specified"
    exit 1
fi

# check if env vars are specified
if [[ $* == *--env=* ]]; then
    env_vars=$(echo $* | sed -e 's/.*--env=//' -e 's/ .*//')
    echo "env vars: $env_vars"
    export $env_vars
fi

# check if args are specified
if [[ $* == *--args=* ]]; then
    args=$(echo $* | sed -e 's/.*--args=//' -e 's/ .*//')
    echo "args: $args"
fi

# Check if the program is already running
if pgrep "$app" > /dev/null
then
    # If it's running, bring its window to the front
    wmctrl -xa "$app"
else
    # If it's not running, start a new instance of the program
    $app $args &
fi
