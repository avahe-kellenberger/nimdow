# Package
version       = "0.0.1"
author        = "avahe-kellenberger"
description   = "A window manager written in nim"
license       = "GPL v2"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["nimdow"]

# Deps
requires "nim >= 1.0"
requires "x11"

# Tasks
task debug, "Create a debug build":
  exec "nim --linedir:on --debuginfo c src/nimdow.nim"

task build, "Create a development build":
  exec "nim c src/nimdow.nim"

task release, "Build for release":
  exec "nim c -d:release --opt:speed src/nimdow.nim"

