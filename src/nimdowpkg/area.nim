type Area* = tuple[x, y: int, width, height: uint]

proc contains*(this: Area, x, y: int): bool =
  return
    x >= this.x and
    y >= this.y and
    x <= this.x + this.width.int and
    y <= this.y + this.height.int
