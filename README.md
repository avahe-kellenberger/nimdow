# nimdow

A window manager written in [Nim](https://nim-lang.org/)

**NOTE: Nimdow is in Beta but is very usable. Please report any bugs you may find.**

I am using this project to learn Nim, x11, and to replace my build of **dwm** (written in C).

# Table of Contents

1. [Screenshots](#screenshots)
2. [Installation](#installation)
    1. [Building from source](#building)
    2. [Arch Linux (AUR)](#aur)
3. [Command Line Arguments](#cli)
4. [Status Bar](#statusbar)
    1. [Setting the status](#setting-status)
5. [Roadmap](#roadmap)
6. [Testing Locally](#testing)


## Screenshots

![](https://user-images.githubusercontent.com/34498340/84605679-209c3d80-ae6d-11ea-8823-09b2c8626b55.png)

## Installation

### Building from source <a name="building"></a>

1. Ensure you have `nim` and `nimble` installed. My preferred method is to use `choosenim` to install these.
2. Clone this repo
3. Execute `nimble install` from the package directory to install dependencies
4. Execute `nimble release` from the package directory to create a release build (The built binary will be in `./bin/nimdow`)
5. Copy the default config (`config.default.toml`) to `${XDG_CONFIG_HOME}/nimdow/config.toml`, OR to `${HOME}/.config/nimdow/config.toml`.

### AUR

If you are on an Arch Linux based system, use `nimdow-bin` in the AUR to install a pre-built binary.

Default config is stored at `/usr/share/nimdow/config.default.toml`

## Command line arguments <a name="cli"></a>

Currently the only argument that may be provided is a config file path. This was added for testing purposes.

E.g. `$ nimdow ./some-config.toml`

If no argument is provided, we use the config file mentioned in the *Building from source* section.

## Status Bar <a name="statusbar"></a>

The status bar displays:
- The available tags on the top left
- The focused window's title in the center
- The status (set by the user) on the right

### Setting the status <a name="setting-status"></a>

The status is the text read from the root window's name property, which can be set with `xsetroot -name "My status"`.
This is the exact same way `dwm` manages its status. I recommend [reading their page](https://dwm.suckless.org/status_monitor/) about setting statuses.

## Roadmap

### Version 0.5

- [x] Multiple tags (single tag viewed at one time)
- [x] Fullscreen windows
- [x] Multihead support
- [x] User configuration file loaded from $XDG_CONFIG_HOME (or $HOME/.config)
- [x] Status bar integration
- [x] Floating window support
  - [x] Move windows with super + left click
  - [x] Resize windows with super + right click drag
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

## Testing locally (for development) <a name="testing"></a>

0. Create a copy or symlink of the config file in `$XDG_CONFIG_HOME/nimdow/config.toml`
1. Start up Xephyr: `Xephyr -ac -screen 1920x1080 -br -reset -terminate 2> /dev/null :1 &`
2. Execute nimdow on the new display: `DISPLAY=:1 ./nimdow`

