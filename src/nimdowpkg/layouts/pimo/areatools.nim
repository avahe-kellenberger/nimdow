import ../../area

type
  Direction* = enum Up, Down, Left, Right

proc height*(x: Area): uint =
  x.height

proc width*(x: Area): uint =
  x.width

proc topEdge*(x: Area): int =
  x.y

proc bottomEdge*(x: Area): int =
  x.y + x.height.int

proc leftEdge*(x: Area): int =
  x.x

proc rightEdge*(x: Area): int =
  x.x + x.width.int

proc `height=`*(x: var Area, y: uint) =
  x.height = y

proc `width=`*(x: var Area, y: uint) =
  x.width = y

proc `topEdge=`*(x: var Area, y: int) =
  x.y = y

proc `bottomEdge=`*(x: var Area, y: int) =
  x.y = y - x.height.int

proc `leftEdge=`*(x: var Area, y: int) =
  x.x = y

proc `rightEdge=`*(x: var Area, y: int) =
  x.x = y - x.width.int

proc above*(x, y: Area): bool =
  x.bottomEdge < y.topEdge

proc below*(x, y: Area): bool =
  x.topEdge > y.bottomEdge

proc leftOf*(x, y: Area): bool =
  x.rightEdge < y.leftEdge

proc rightOf*(x, y: Area): bool =
  x.leftEdge > y.rightEdge

proc withinRow*(x: int, y: Area): bool =
  x > y.topEdge and x < y.bottomEdge

proc withinColumn*(x: int, y: Area): bool =
  x > y.leftEdge and x < y.rightEdge

proc sameColumn*(x, y: Area): bool =
  x.leftEdge.withinColumn(y) or
  x.rightEdge.withinColumn(y) or
  (x.leftEdge <= y.leftEdge and x.rightEdge >= y.rightEdge)

proc sameRow*(x, y: Area): bool =
  x.topEdge.withinRow(y) or
  x.bottomEdge.withinRow(y) or
  (x.topEdge <= y.topEdge and x.bottomEdge >= y.bottomEdge)

proc opposite*(x: Direction): Direction =
  case x:
  of Left: Right
  of Right: Left
  of Up: Down
  of Down: Up

proc area*(x: Area): uint =
  x.width * x.height

template generalizeForDirection*(d: Direction): untyped =
  template startEdge(x: Area): int =
    if d in {Right, Left}: x.leftEdge
    else: x.topEdge

  template endEdge(x: Area): int =
    if d in {Right, Left}: x.rightEdge
    else: x.bottomEdge

  template leadingEdge(x: Area): int =
    if towardsStart: x.startEdge
    else: x.endEdge

  template trailingEdge(x: Area): int =
    if towardsStart: x.endEdge
    else: x.startEdge

  template size(x: Area): uint =
    if d in {Right, Left}: x.width
    else: x.height

  #template pureRequestedSize(x: Area): uint =
  #  if d in {Right, Left}: x.requested.w
  #  else: x.requested.h

  template `startEdge=`(x: Area, y: int) =
    if d in {Right, Left}: x.leftEdge = y
    else: x.topEdge = y

  template `endEdge=`(x: Area, y: int) =
    if d in {Right, Left}: x.rightEdge = y
    else: x.bottomEdge = y

  template `leadingEdge=`(x: Area, y: int) =
    if towardsStart: x.startEdge = y
    else: x.endEdge = y

  template `trailingEdge=`(x: Area, y: int) =
    if towardsStart: x.endEdge = y
    else: x.startEdge = y

  template `size=`(cr: Area, n: int or uint) =
    if d in {Right, Left}:
      #if towardsEnd: cr.x += cr.width.int - n.int
      cr.width = n.uint
    else:
      #if towardsEnd: cr.y += cr.height.int - n.int
      cr.height = n.uint

  #template `pureRequestedSize=`(x: Area, n: uint) =
  #  if d in {Right, Left}: x.requested.w = n
  #  else: x.requested.h = n

  #template requestedSize(x: Area): uint {.inject.} =
  #  if d in {Right, Left}:
  #    if x.expandedX: 1920 else: x.requested.w
  #  else:
  #    if x.expandedY: 1080 else: x.requested.h

  template sameDir(x, y: Area): bool {.inject.} =
    if d in {Right, Left}: x.sameRow(y)
    else: x.sameColumn(y)

  template otherDir(x, y: Area): bool {.inject.} =
    if d in {Right, Left}: x.sameColumn(y)
    else: x.sameRow(y)

  template before(x, y: int): bool =
    if towardsStart: x < y
    else: x > y

  template after(x, y: uint): bool =
    if towardsStart: x > y
    else: x < y

  template towardsStart(): bool {.inject.} =
    if d in {Left, Up}: true
    else: false

  template towardsEnd(): bool {.inject.} =
    if d in {Right, Down}: true
    else: false

  template offsetTrailing(this: untyped): uint =
    case d
    of Left: this.offset.right
    of Right: this.offset.left
    of Up: this.offset.bottom
    of Down: this.offset.top

  template offsetLeading(this: untyped): uint =
    case d
    of Left: this.offset.left
    of Right: this.offset.right
    of Up: this.offset.top
    of Down: this.offset.bottom

  template offsetStart(this: untyped): uint =
    case d
    of Left, Right: this.offset.left
    of Up, Down: this.offset.top

  template offsetEnd(this: untyped): uint =
    case d
    of Left, Right: this.offset.right
    of Up, Down: this.offset.bottom

  template offsetTot(this: untyped): uint =
    this.offsetEnd + this.offsetStart

  template monitorSize(this: untyped): uint =
    if d in {Right, Left}: this.monitorArea.width
    else: this.monitorArea.height

  template dimensionSize(this: untyped): uint =
    this.monitorSize - this.offsetTot()

  template horizontal(): bool =
    if d in {Right, Left}: true
    else: false

  template vertical(): bool =
    if d in {Right, Left}: false
    else: true

proc collision*(rect1, rect2: Area): Area =
  ## Checks if the two given rectangles intersects with each other and returns
  ## the smallest rectangle that contains the collision. Copied from SDLGamelib
  #new result
  let
    x1inx2 = (rect1.x>=rect2.x and rect1.x<rect2.x+rect2.width.int)
    x2inx1 = (rect2.x>=rect1.x and rect2.x<rect1.x+rect1.width.int)
    y1iny2 = (rect1.y>=rect2.y and rect1.y<rect2.y+rect2.height.int)
    y2iny1 = (rect2.y>=rect1.y and rect2.y<rect1.y+rect1.height.int)
  if
    (x1inx2 or x2inx1) and
    (y1iny2 or y2iny1):
      if x2inx1:
        result.x = rect2.x
        result.width = (rect1.x+rect1.width.int-rect2.x).uint
        if result.width > rect2.width:
          result.width = rect2.width
      else:
        result.x = rect1.x
        result.width = (rect2.x+rect2.width.int-rect1.x).uint
        if result.width > rect1.width:
          result.width = rect1.width
      if y2iny1:
        result.y = rect2.y
        result.height = (rect1.y+rect1.height.int-rect2.y).uint
        if result.height > rect2.height:
          result.height = rect2.height
      else:
        result.y = rect1.y
        result.height = (rect2.y+rect2.height.int-rect1.y).uint
        if result.height > rect1.height:
          result.height = rect1.height
      return result
