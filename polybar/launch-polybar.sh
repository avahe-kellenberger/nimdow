#!/usr/bin/env bash

for m in $(polybar --list-monitors | cut -d":" -f1); do
    MONITOR=$m polybar -c $HOME/.config/polybar/nimdow --reload nimdow &
done

