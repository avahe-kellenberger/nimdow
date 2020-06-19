# Package
version       = "0.5.5"
author        = "avahe-kellenberger"
description   = "A window manager written in nim"
license       = "GPL v2"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["nimdow"]

# Deps
requires "nim >= 1.0"
requires "x11"
requires "parsetoml"

# Tasks
task debug, "Create a debug build":
  exec "nim -o:bin/nimdow --linedir:on --debuginfo c src/nimdow.nim"

task build, "Create a development build":
  exec "nim -o:bin/nimdow c src/nimdow.nim"

task release, "Build for release":
  exec "nim c -o:bin/nimdow -d:release --opt:speed src/nimdow.nim"

