# Package
version = "0.7.33"
author = "avahe-kellenberger"
description = "A window manager written in nim"
license = "GPL v2"
srcDir = "src"
installExt = @["nim"]
bin = @["nimdow"]

# Deps
requires "nim >= 1.4.0"
requires "x11"
requires "parsetoml"
requires "nimtest >= 0.1.0"
requires "https://github.com/avahe-kellenberger/safeset"

# Tasks
task debug, "Create a debug build":
  exec "nim --multimethods:on -o:bin/nimdow --linedir:on --debuginfo c src/nimdow.nim"

task release, "Build for release":
  exec "./build.sh"

task lint, "Lint all *.nim files":
  exec "nimpretty --indent:2 --maxLineLen:106 */**.nim"

