# Package

version       = "0.0.1"
author        = "avahe-kellenberger"
description   = "A window manager written in nim"
license       = "GPL v2"
srcDir        = "nimdowpkg"
installExt    = @["nim"]
bin           = @["nimdow"]

requires "nim >= 1.0"
requires "x11"

task build, "Create a development build":
  exec "nim c -r src/nimdow.nim"

task release, "Build for release":
  exec "nim c -d:release --opt:speed src/nimdow.nim"

