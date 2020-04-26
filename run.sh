#!/usr/bin/env bash

nimble build || exit 1
Xephyr -br -ac -reset -screen 800x600 :1 &
sleep 1s
export DISPLAY=:1
sxhkd &
./nimdow
