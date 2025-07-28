#!/bin/bash

NID=0

for i in {0..100..10}
    do
          NID=$(notify-send -p -r $NID $i)
          sleep 0.5
    done