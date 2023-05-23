# nimdow

A window manager written in [Nim](https://nim-lang.org/)

**NOTE: Nimdow is in Beta but is very usable. Please report any bugs you may find.**

I am using this project to learn Nim, x11, and to replace my build of **dwm** (written in C).

**Discord community:** https://discord.gg/vPCumzeqqa

[See the progress of development in the local Kanban Board](https://github.com/avahe-kellenberger/nimdow/projects/1?fullscreen=true)

# Table of Contents

1. [Screenshots](#screenshots)
2. [Installation](#installation)
    1. [Building from source](#building)
    2. [Arch Linux (AUR)](#aur)
3. [Config File](#config)
4. [Command Line Arguments](#cli)
5. [Command Line Client](#cli-client)
6. [Status Bar](#statusbar)
7. [Issues with Java Applications](#issues-with-java-applications)
8. [Roadmap](#roadmap)
9. [Testing Locally](#testing)


## Screenshots

![](https://user-images.githubusercontent.com/34498340/187017440-95f191ae-5701-45ce-9481-9c1f5fd450dc.png)
![](https://user-images.githubusercontent.com/34498340/132368685-570a2629-f948-4f24-9ab8-00804824a497.png)
![](https://user-images.githubusercontent.com/34498340/84605679-209c3d80-ae6d-11ea-8823-09b2c8626b55.png)

## Installation

### Building from source <a name="building"></a>

1. Ensure you have `nim` (version 1.2.0 or higher) and `nimble` installed. My preferred method is to use `choosenim` to install these.
2. Clone this repo
3. Execute `nimble install` from the package directory to install dependencies
4. Execute `nimble release` from the package directory to create a release build (The built binary will be in `./bin/nimdow`)
5. Copy the default config (`config.default.toml`) to `${XDG_CONFIG_HOME}/nimdow/config.toml`, OR to `${HOME}/.config/nimdow/config.toml`.

### AUR

If you are on an Arch Linux based system, use `nimdow-bin` in the AUR to install a pre-built binary.

Default config is stored at `/usr/share/nimdow/config.default.toml`

## Nixos

If you are on Nixos, you can set `services.xserver.windowManager.nimdow.enable=true;` to install and
enable nimdow in your login manager. (in `nixos-unstable` or in stable from 2023-05 release).

## Config File <a name="config"></a>

Nimdow searches for a config file in 3 locations in this order:

1. `${XDG_CONFIG_HOME}/nimdow/config.toml`
2. `${HOME}/.config/nimdow/config.toml`
3. `/usr/share/nimdow/config.default.toml`

If no config file is found, Nimdow will not launch.

**See [the wiki](https://github.com/avahe-kellenberger/nimdow/wiki/User-Configuration-File) for information about the specifics of the config file.**

## Command Line Arguments <a name="cli"></a>

- Providing an alternative config file, e.g. `nimdow --config ./some-config.toml`
- Version information: `nimdow -v` or `nimdow --version`

## Command Line Client <a name="cli-client"></a>

Nimdow controls can be executed via the cli client.

See [the wiki page](https://github.com/avahe-kellenberger/nimdow/wiki/CLI-Client) for a list of commands,
or read the **man page**.

## Status Bar <a name="statusbar"></a>

The status bar displays:
- The available tags on the top left
- The focused window's title in the center
- The status (set by the user) on the right

### Setting the status <a name="setting-status"></a>

See the [wiki page](https://github.com/avahe-kellenberger/nimdow/wiki/Setting-the-status) about statuses.

### Emojis Not showing up / some characters invisible

In short, there's a bug in the xft library most distros use.

[This fork of xft](https://gitlab.freedesktop.org/xorg/lib/libxft) has a fix for emojis and other font issues.

If using an Arch Linux based distro, there is [libxft-bgra-git](https://aur.archlinux.org/packages/libxft-bgra-git/) in the AUR.

## Issues with Java Applications

### The fix

There are multiple fixes, per the [arch wiki](https://wiki.archlinux.org/index.php/Java#Gray_window,_applications_not_resizing_with_WM,_menus_immediately_closing).

Fix #1:
For jre7-openjdk or jre8-openjdk, append the line `export _JAVA_AWT_WM_NONREPARENTING=1` in `/etc/profile.d/jre.sh`.
Then, source the file `/etc/profile.d/jre.sh` or log out and log back in.

Fix #2:
For last version of JDK append line `export AWT_TOOLKIT=MToolkit` in `~/.xinitrc` before `exec nimdow`.

Fix #3:
Try to use [wmname](https://tools.suckless.org/x/wmname/) with line `wmname compiz` in your `~/.xinitrc`.

Fix #4:
For Oracle's JRE/JDK, use [SetWMName](https://wiki.haskell.org/Xmonad/Frequently_asked_questions#Using_SetWMName).
However,
its effect may be canceled when also using XMonad.Hooks.EwmhDesktops.
In this case,
appending `>> setWMName "LG3D"` to the LogHook may help.

### Why is this happening?

The standard Java GUI toolkit has a hard-coded list of "non-reparenting" window managers.
Nimdow is not (yet) included in this list.

## Roadmap

See the [1.0 release project board](https://github.com/avahe-kellenberger/nimdow/projects/1)

## Testing locally (for development) <a name="testing"></a>

0. Create a copy or symlink of the config file in `$XDG_CONFIG_HOME/nimdow/config.toml`
1. Start up Xephyr: `Xephyr -ac -screen 1920x1080 -br -reset -terminate 2> /dev/null :1 &`
2. Execute nimdow on the new display: `DISPLAY=:1 ./nimdow`

