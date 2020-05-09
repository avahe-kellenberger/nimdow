#!/usr/bin/env bash

nimble build || exit 1
Xephyr -br -ac -reset -screen 1920x1080 :1 &
sleep 1s
export DISPLAY=:1
sxhkd &
xrdb $HOME/.Xresources &
./nimdow
