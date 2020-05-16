#!/usr/bin/env bash

config="${XDG_CONFIG_HOME}/nimdow/config.toml"
if [ ! -f "$config" ]; then
  mkdir -p "${XDG_CONFIG_HOME}/nimdow"
  ln -s "$(pwd)/config.default.toml" "$config"
  printf "Created symlink to %s\n" "$config"
fi

nimble build || exit 1
Xephyr -br -ac -reset -screen 1920x1080 :1 &
sleep 1s
export DISPLAY=:1
sxhkd &
xrdb $HOME/.Xresources &
./nimdow &

polybar -c ~/.config/polybar/i3-config i3 &
nm-applet &
