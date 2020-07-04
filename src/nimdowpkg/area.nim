type Area* = tuple[x, y: int, width, height: uint]

proc center*(this: Area): tuple[x, y: float] =
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

