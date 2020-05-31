# nimdow

A window manager written in [Nim](https://nim-lang.org/)

**NOTE: This is a WIP but is very usable. Please report any bugs if you find any.**

I am using this project to learn Nim, x11, and to replace my build of **dwm** (written in C).

## Screenshots

![](https://user-images.githubusercontent.com/34498340/82363615-0ee58880-99dc-11ea-8290-fec33849095c.png)

## Installation

### Building from source

1. Ensure you have `nim` and `nimble` installed. My preferred method is to use `choosenim` to install these.
2. Clone this repo
3. Execute `nimble release` from the package directory to create a release build (The built binary will be in `./bin/nimdow`)
4. Copy the default config (`config.default.toml`) to `${XDG_CONFIG_HOME}/nimdow/config.toml`, OR to `${HOME}/.config/nimdow/config.toml`. Nimdow will NOT run if you skip this step.

### AUR

If you are on an Arch Linux based system, use `nimdow-bin` in the AUR to install a pre-built binary.

## Command line arguments

Currently the only argument that may be provided is a config file path. This was added for testing purposes.

E.g. `$ nimdow ./some-config.toml`

If no argument is provided, we use the config file mentioned in the *Building from source* section.

## Polybar config

If you would like to use Polybar with Nimdow, there is a config file [here](https://github.com/avahe-kellenberger/nimdow/tree/master/polybar).

To start polybar:

```sh
$ polybar -c path/to/config nimdow
```

## Roadmap

### Version 0.5

- [x] Multiple tags (single tag viewed at one time)
- [x] Fullscreen windows
- [x] Multihead support
- [x] User configuration file loaded from $XDG_CONFIG_HOME (or $HOME/.config)
- [x] Status bar integration (single monitor - integrated with Polybar)
  - [ ] Multihead status bar integration (Writing our own bar - See [#29](https://github.com/avahe-kellenberger/nimdow/issues/29))
- [ ] Floating window support
  - [ ] Move windows with super + left click
  - [ ] Resize windows with super + right click drag
- [x] Layouts:
  - [x] Master/stack
- [x] Keybindings:
  - [x] Close window
  - [x] Toggle fullscreen
  - [x] Navigate windows
  - [x] Navigate tags
  - [x] Move windows in stack
  - [x] Move windows between tags

### Version 1.0

- TBA (partial list, still in discussion)
- [ ] Layouts
  - [ ] Monocle
- [ ] Keybindings:
  - [x] Move window between monitors
  - [ ] Add/remove window per tag
  - [ ] View multiple tags
  - [ ] Assign single window to multiple tags
  - [ ] Swap tags between monitors
  - [ ] Reload Nimdow (to apply configuration changes)
  - [ ] Switch layout to master/stack
  - [ ] Switch layout to monocle

## Testing locally (for development)

0. Create a copy or symlink of the config file in `$XDG_CONFIG_HOME/nimdow/config.toml`
1. Start up Xephyr: `Xephyr -ac -screen 1920x1080 -br -reset -terminate 2> /dev/null :1 &`
2. Execute nimdow on the new display: `DISPLAY=:1 ./nimdow`


