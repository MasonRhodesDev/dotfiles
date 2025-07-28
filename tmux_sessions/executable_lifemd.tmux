#!/bin/bash

session=lifemd
repo_location=$(readlink -f ~/repos)

SESSIONEXISTS=$(tmux list-sessions | grep $session)
if [ "$SESSIONEXISTS" = "" ]
then
    tmux new-session -d -s $session
    
    window=0
    tmux rename-window -t $session:$window 'term'
    tmux send-keys -t $session:$window 'cd '$repo_location'' C-m

    window=$((window+1))
    tmux new-window -t $session:$window -n 'backend'
    tmux send-keys -t $session:$window 'cd '$repo_location'/lifemd/physician-portal/back-end' C-m
    tmux send-keys -t $session:$window 'npm run start' C-m
    tmux split-window -v
    tmux send-keys -t $session:$window 'cd ~/Desktop/proxy && node .' C-m
    tmux split-window -h
    tmux send-keys -t $session:$window 'cd '$repo_location'/lifemd/scripts' C-m
    tmux select-pane -t 0
    tmux split-window -h
    tmux send-keys -t $session:$window 'cd '$repo_location'/lifemd/patient-portal/back-end' C-m
    tmux send-keys -t $session:$window 'npm run start' C-m
    
    window=$((window+1))
    tmux new-window -t $session:$window -n 'fe'
    tmux send-keys -t $session:$window 'cd '$repo_location'/care-patient-portal-web' C-m
    tmux send-keys -t $session:$window 'yarn start'
    tmux split-window -h
    tmux send-keys -t $session:$window 'cd '$repo_location'/care-physician-portal-web' C-m
    tmux send-keys -t $session:$window 'yarn start'

    window=$((window+1))
    tmux new-window -t $session:$window -n 'savvy'
    tmux send-keys -t $session:$window 'cd '$repo_location'/savvy_bootstrap' C-m
    tmux send-keys -t $session:$window 'yarn dev'
fi

tmux attach-session -t $session:0
