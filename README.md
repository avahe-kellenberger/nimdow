# nimdow

A window manager written in [Nim](https://nim-lang.org/)

**NOTE: This is a WIP and is not usable (yet).**

I am using this project to learn Nim, x11, and to replace my build of **dwm** (written in C).

## Building

`nimble build` for a quick development build

`nimble release` to create a release build

The above commands seem to fail for some reason, but compiling with nim itself works just fine. If you run into trouble, try `nim c src/nimdow.nim`

## Running locally

1. Start up Xephyr: `Xephyr -ac -screen 1920x1080 -br -reset -terminate 2> /dev/null :1 &`
2. Execute nimdow on the new display: `DISPLAY=:1 ./nimdow`

