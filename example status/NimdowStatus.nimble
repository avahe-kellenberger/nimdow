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
  let nimCmd = "nimble build -d:release -d:danger -d:ssl"
  exec nimCmd
