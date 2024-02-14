# Package
version       = "0.1.0"
author        = "DrunkenAlcoholic"
description   = "A simple status bar for Nimdow WM"
license       = "MIT"
srcDir        = "src"
bin           = @["NimdowStatus"]


# Dependencies
requires "nim >= 1.0.0"

# taks
task release, "Build with compiler flags.":
  let nimCmd = "nimble build --boundChecks:off -d:danger -d:ssl -d:flto --opt:speed"
  exec nimCmd
