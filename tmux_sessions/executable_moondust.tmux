#!/bin/bash

session=moondust
repo_location=$(readlink -f ~/repos)

SESSIONEXISTS=$(tmux list-sessions | grep $session)
if [ "$SESSIONEXISTS" = "" ]
then
    tmux new-session -d -s $session
    
    window=0
    tmux rename-window -t $session:$window 'term'
    tmux send-keys -t $session:$window 'cd '$repo_location'' C-m
    
    window=$((window+1))
    tmux new-window -t $session:$window -n 'fe'
    tmux send-keys -t $session:$window 'cd '$repo_location'/quiz-builder-front-end' C-m
    tmux send-keys -t $session:$window 'pnpm run dev' C-m
    tmux split-window -h
    tmux send-keys -t $session:$window 'cd '$repo_location'/stardust-front-end' C-m
    tmux send-keys -t $session:$window 'pnpm run storybook:previews' C-m
    tmux split-window -v
    tmux send-keys -t $session:$window 'cd '$repo_location'/stardust-front-end' C-m
    tmux send-keys -t $session:$window 'pnpm run storybook' C-m
fi

tmux attach-session -t $session:0
