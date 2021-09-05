# Package
version       = "0.7.28"
author        = "avahe-kellenberger"
description   = "A window manager written in nim"
license       = "GPL v2"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["nimdow"]

# Deps
requires "nim >= 1.4.0"
requires "x11"
requires "parsetoml"

# Tasks
task debug, "Create a debug build":
  exec "nim --multimethods:on -o:bin/nimdow --linedir:on --debuginfo c src/nimdow.nim"

task release, "Build for release":
  exec "./build.sh"

