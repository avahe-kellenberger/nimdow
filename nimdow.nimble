# Package
version = "0.7.38"
author = "avahe-kellenberger"
description = "A window manager written in nim"
license = "GPL v2"
srcDir = "src"
installExt = @["nim"]
bin = @["nimdow"]

# Deps
requires "nim >= 2.0.0"
requires "x11"
requires "parsetoml"
requires "nimtest >= 0.1.0"
requires "safeseq >= 1.0.0"

# Tasks
task debug, "Create a debug build":
  exec "nim -o:bin/nimdow --deepcopy:on --linedir:on --debuginfo c src/nimdow.nim"

task release, "Build for release":
  exec "./build.sh"

task lint, "Lint all *.nim files":
  exec "nimpretty --indent:2 --maxLineLen:106 */**.nim"

