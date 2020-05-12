# nimdow

A window manager written in [Nim](https://nim-lang.org/)

**NOTE: This is a WIP and currently only usable on single monitor setups**

I am using this project to learn Nim, x11, and to replace my build of **dwm** (written in C).

## Building

`nimble build` for a quick development build

`nimble release` to create a release build

## Running locally

0. Create a copy or symlink of the config file in `$XDG_CONFIG_HOME/nimdow/config.toml`
1. Start up Xephyr: `Xephyr -ac -screen 1920x1080 -br -reset -terminate 2> /dev/null :1 &`
2. Execute nimdow on the new display: `DISPLAY=:1 ./nimdow`

# Roadmap

## Version 0.5

- [x] Multiple tags (single tag viewed at one time)
- [x] Fullscreen windows
- [ ] Multihead support
- [ ] User configuration file loaded from $XDG_CONFIG_HOME (or $HOME/.config)
- [ ] Status bar integration (probably 3rd party status bar)
- [ ] Layouts:
  - [x] Master/stack
  - [ ] Monocle
- [ ] Keybindings:
  - [x] Close window
  - [x] Toggle fullscreen
  - [ ] Switch layout to master/stack
  - [ ] Switch layout to monocle
  - [x] Navigate windows
  - [x] Navigate tags
  - [x] Move windows in stack
  - [x] Move windows between tags
  - [ ] Add/remove window per tag

## Version 1.0

- TBA (partial list, still in discussion)
- [ ] Floating window support
- [ ] Keybindings:
  - [ ] View multiple tags
  - [ ] Assign single window to multiple tags
  - [ ] Move window between screens
  - [ ] Swap tags between screens
  - [ ] Reload Nimdow (to apply configuration changes)

