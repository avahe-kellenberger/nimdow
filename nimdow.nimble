# Package
version       = "0.7.1"
author        = "avahe-kellenberger"
description   = "A window manager written in nim"
license       = "GPL v2"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["nimdow"]

# Deps
requires "nim >= 1.2.0"
requires "x11"
requires "parsetoml"

# Tasks
task debug, "Create a debug build":
  exec "nim --multimethods:on -o:bin/nimdow --linedir:on --debuginfo c src/nimdow.nim"

task build, "Create a development build":
  exec "nim --multimethods:on -o:bin/nimdow c src/nimdow.nim"

task release, "Build for release":
  exec "nim c --multimethods:on -o:bin/nimdow -d:release --opt:speed src/nimdow.nim"

