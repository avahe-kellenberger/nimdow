#!/usr/bin/env bash

config="${XDG_CONFIG_HOME}/nimdow/config.toml"
if [ ! -f "$config" ]; then
  mkdir -p "${XDG_CONFIG_HOME}/nimdow"
  ln -s "$(pwd)/config.default.toml" "$config"
  printf "Created symlink to %s\n" "$config"
fi

nimble debug || exit 1
Xephyr -br -ac -reset -screen 1920x1080 :1 &
sleep 1s
export DISPLAY=:1
xrdb $HOME/.Xresources &
./bin/nimdow "./config.default.toml" &

polybar -c ./polybar/nimdow nimdow &
nm-applet &
~/.fehbg &
