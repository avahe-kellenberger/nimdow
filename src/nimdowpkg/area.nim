import math

import point

type Area* = tuple[x, y: int, width, height: uint]

proc center*(this: Area): Point[float] =
  ## Calculates the center of the area.
  return (
    this.x.float + (this.width.int) / 2,
    this.y.float + (this.height.int) / 2
  )

proc contains*(this: Area, x, y: int): bool =
  return
    x >= this.x and
    y >= this.y and
    x < this.x + this.width.int and
    y < this.y + this.height.int

proc distanceToCenterSquared*(this: Area, x, y: int): float =
  let center = this.center()
  return pow(abs(center.x - x.float), 2f) + pow(abs(center.y - y.float), 2f)

proc `$`*(this: Area): string =
  "[x: " & $this.x & ", y: " & $this.y & ", width: " & $this.width & ", height: " & $this.height & "]"

