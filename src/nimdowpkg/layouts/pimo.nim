import
  x11 / [x, xlib],
  parsetoml,
  strutils,
  sequtils,
  layout,
  ../client,
  ../area,
  ../logger,
  ../taggedclients,
  pimo/areatools
import std/algorithm except shuffle

converter intToCint(x: int): cint = x.cint
converter intToCUint(x: int): cuint = x.cuint

const layoutName: string = "pimo"

type
  TrackedClient = ref object
    client: Client
    requested: Area
    expandX: bool
    expandY: bool
  Solution = object
    dir1, dir2: Direction
    bounding: Area
    solution: seq[Area]
    newPosition: Area
    overlaps: seq[TrackedClient]
    overlapX: int
    overlapY: int
  Path = object
    requested: uint
    path: seq[TrackedClient]
  PimoLayout* = ref object of Layout
    offset: LayoutOffset
    trackedClients: seq[TrackedClient]
    settings: PimoLayoutSettings
  PimoLayoutSettings* = ref object of LayoutSettings
    gapSize*: uint
    outerGap*: uint
    resizeStep*: uint
  Commands = enum
    pExpandX = "expandx"
    pExpandY = "expandy"
    pGrowX = "growx"
    pGrowY = "growy"
    pShrinkX = "shrinkx"
    pShrinkY = "shrinky"
    pMoveLeft = "moveleft"
    pMoveRight = "moveright"
    pMoveUp = "moveup"
    pMoveDown = "movedown"
    pFocusLeft = "focusleft"
    pFocusRight = "focusright"
    pFocusUp = "focusup"
    pFocusDown = "focusdown"

proc shuffle(this: PimoLayout, dir: Direction): bool {.discardable.} =
  let clients = this.trackedClients
  generalizeForDirection(dir)
  let limit = this.dimensionSize
  var
    placed: seq[TrackedClient]
    sortedEdge =
      if towardsStart: clients.sortedByIt(it.client.area.startEdge)
      else: clients.sortedByIt(limit.int - (it.client.area.endEdge))
  for edge in sortedEdge:
    let square = edge.client.area
    var closestEdge =
      if towardsStart: this.offsetLeading.int
      else: limit.int - square.size.int + this.offsetTrailing.int
    for placedEdge in placed:
      let placed = placedEdge.client.area
      if square.sameDir(placed):
        closestEdge =
          if towardsStart: max(closestEdge, placed.endEdge)
          else: min(closestEdge, placed.startEdge - square.size.int)
    result = result or square.startEdge != closestEdge.cint# - 1
    if dir in {Left, Right}:
      edge.client.area.x = closestEdge# - 1
    else:
      edge.client.area.y = closestEdge# - 1
    placed.add edge

proc shuffle(this: PimoLayout, d1, d2: Direction) =
  var moved = true
  while moved:
    moved = this.shuffle(d1) and moved
    moved = this.shuffle(d2) and moved

proc calcBounding(squares: seq[TrackedClient]): Area =
  if squares.len == 0:
    return
  result = squares[0].client.area
  result.width += result.x.uint
  result.height += result.y.uint
  for i in squares.low+1..squares.high:
    result.x = min(squares[i].client.area.x, result.x)
    result.y = min(squares[i].client.area.y, result.y)
    result.width = max(squares[i].client.area.x.uint + squares[i].client.area.width, result.width)
    result.height = max(squares[i].client.area.y.uint + squares[i].client.area.height, result.height)
  result.width -= result.x.uint
  result.height -= result.y.uint

proc testSolution(this: PimoLayout, newSquare: TrackedClient, dir1, dir2: Direction): Solution =
  result.dir1 = dir1
  result.dir2 = dir2
  this.shuffle(dir1, dir2)
  if dir1 == Left or dir2 == Left:
    newSquare.client.area.x = this.monitorArea.width.int - this.offset.right.int - newSquare.client.area.width.int
  else:
    newSquare.client.area.x = this.offset.left.int
  if dir1 == Up or dir2 == Up:
    newSquare.client.area.y = this.monitorArea.height.int - this.offset.bottom.int - newSquare.client.area.height.int
  else:
    newSquare.client.area.y = this.offset.top.int
  var overlaps: seq[TrackedClient]
  for square in this.trackedClients:
    if collision(square.client.area, newSquare.client.area).area != 0:
      overlaps.add square
  let ratio = (this.monitorArea.width.int - this.offset.left.int - this.offset.right.int).float / (this.monitorArea.height.int - this.offset.top.int - this.offset.bottom.int).float
  if overlaps.len == 0:
    this.trackedClients.add newSquare
    var backup = this.trackedClients.mapIt(it.client.area)
    this.shuffle(dir1, dir2)
    let b1 = calcBounding(this.trackedClients)
    #swap(this.trackedClients, backup)
    for i, client in this.trackedClients.mpairs: swap(client.client.area, backup[i])
    this.shuffle(dir2, dir1)
    let b2 = calcBounding(this.trackedClients)
    if (b1.area == b2.area and abs(b1.width.float / b1.height.float - ratio) <= abs(b2.width.float / b2.height.float - ratio)) or
       (b1.area < b2.area):
      result.bounding = b1
      result.solution = backup
    else:
      result.bounding = b2
      result.solution = this.trackedClients.mapIt(it.client.area)
    result.newPosition = newSquare.client.area
    this.trackedClients.del(this.trackedClients.high) # Remove new one again, will be added later
  else:
    result.bounding = (x: this.offset.left.int, y: this.offset.top.int, width: this.monitorArea.width - this.offset.left - this.offset.right, height: this.monitorArea.height - this.offset.top - this.offset.bottom)
    result.overlaps = overlaps
    result.overlapX = 0
    result.overlapY = 0
    for square in overlaps:
      let col = square.client.area.collision(newSquare.client.area)
      result.overlapX += col.width.int
      result.overlapY += col.height.int
    result.solution = this.trackedClients.mapIt(it.client.area)
    result.newPosition = newSquare.client.area

proc longestPath(this: PimoLayout, x: TrackedClient, dir: Direction): Path =
  #echo "Checking ", x
  let
    usableWidth = this.monitorArea.width - this.offset.left - this.offset.right
    usableHeight = this.monitorArea.height - this.offset.top - this.offset.bottom
  generalizeForDirection(dir)
  template requestedSize(x: TrackedClient): uint {.inject.} =
    if dir in {Right, Left}:
      if x.expandX: usableWidth else: x.requested.width
    else:
      if x.expandY: usableHeight else: x.requested.height
  if towardsStart and x.client.area.startEdge == 0:
    #echo "Reached end with window ", x.count
    return Path(requested: x.requestedSize, path: @[x])
  if towardsEnd and x.client.area.endEdge == (if dir == Right: usableWidth else: usableHeight).int:
    #echo "Reached end with window ", x.count
    return Path(requested: x.requestedSize, path: @[x])

  for square in this.trackedClients:
    if square.client.window == x.client.window: continue
    #echo square.startEdge, " ", x.endEdge
    #echo square.endEdge, " ", x.startEdge
    if (towardsEnd and square.client.area.startEdge == x.client.area.endEdge) or
       (towardsStart and square.client.area.endEdge == x.client.area.startEdge):
      #echo "Found square on edge: ", square
      if square.client.area.sameDir x.client.area:
        #echo "And it's in the same column/row"
        let path = this.longestPath(square, dir)
        if path.requested > result.requested:
          result = path

  result.requested += x.requestedSize
  result.path.add x

proc solveConflict(this: PimoLayout, newSquare: TrackedClient, s: Solution) =
  var
    hDir, vDir: Direction
  let
    usableWidth = this.monitorArea.width - this.offset.left - this.offset.right
    usableHeight = this.monitorArea.height - this.offset.top - this.offset.bottom
  if s.dir1 == Left or s.dir2 == Left:
    newSquare.client.area.x = usableWidth.int - newSquare.client.area.width.int
    hDir = Left
  else:
    newSquare.client.area.x = this.offset.left.int
    hDir = Right
  if s.dir1 == Up or s.dir2 == Up:
    newSquare.client.area.y = usableHeight.int - newSquare.client.area.height.int
    vDir = Up
  else:
    newSquare.client.area.y = this.offset.top.int
    vDir = Down

  var overlaps = s.overlaps

  while overlaps.len != 0:
    var
      dir: Direction
      path: Path
    for square in overlaps:
      let
        col = square.client.area.collision(newSquare.client.area)
        cdir = if col.width.float / square.client.area.width.float < col.height.float / square.client.area.height.float: hDir else: vDir
        cpath = this.longestPath(square, cdir)
      if cpath.requested > path.requested:
        path = cpath
        dir = cdir

    generalizeForDirection(dir)
    var
      overflow = path.requested.int + newSquare.client.area.size.int - this.dimensionSize.int
      correction = overflow div (path.path.len + 1)
    overflow -= correction

    if dir in {Left, Right}:
      newSquare.client.area.width -= correction.uint
      if towardsStart:
        newSquare.client.area.x += correction
    else:
      newSquare.client.area.height -= correction.uint
      if towardsStart:
        newSquare.client.area.y += correction

    for i, square in path.path:
      correction = overflow div (path.path.len - i) # Recalculate each step to avoid remainder
      overflow -= correction
      if dir in {Left, Right}:
        square.client.area.width -= correction.uint
        if towardsEnd:
          square.client.area.x += correction
      else:
        square.client.area.height -= correction.uint
        if towardsEnd:
          square.client.area.y += correction

    this.shuffle(dir)

    overlaps = @[]
    for square in this.trackedClients:
      let col = square.client.area.collision(newSquare.client.area)
      if col.area != 0:
        overlaps.add square

  this.trackedClients.add newSquare
  this.shuffle(s.dir1, s.dir2)

proc iterGrow(this: PimoLayout, dir: Direction) =
  generalizeForDirection(dir)
  template resize(square: TrackedClient, change: int): untyped =
    square.client.area.size = square.client.area.size + change.uint
  template pureRequestedSize(x: TrackedClient): uint =
    if dir in {Right, Left}: x.requested.width
    else: x.requested.height
  template requestedSize(x: TrackedClient): uint {.inject.} =
    if dir in {Right, Left}:
      if x.expandX: usableWidth else: x.requested.width
    else:
      if x.expandY: usableHeight else: x.requested.height
  let
    usableWidth = this.monitorArea.width - this.offset.left - this.offset.right
    usableHeight = this.monitorArea.height - this.offset.top - this.offset.bottom
    sortedEdge =
      if towardsStart: this.trackedClients.sortedByIt(it.client.area.startEdge)
      else: this.trackedClients.sortedByIt((if dir in {Right, Left}: usableWidth else: usableHeight).int - it.client.area.endEdge)
  for square in this.trackedClients:
    if (horizontal and square.expandX) or (vertical and square.expandY):
      square.resize(min(0, square.pureRequestedSize.int - square.client.area.size.int))
  var resized = true
  this.shuffle(dir.opposite)
  template growForSize(selectedSize: untyped): untyped =
    while resized:
      resized = false
      var oldPos: Table[Window, int]
      for square in sortedEdge:
        if square.selectedSize < square.client.area.size:
          resized = true
          square.resize(square.selectedSize.int - square.client.area.size.int)
        oldPos[square.client.window] = square.client.area.leadingEdge
      this.shuffle(dir)
      for square in sortedEdge:
        if square.selectedSize != square.client.area.size:
          let change = (abs(square.client.area.leadingEdge - oldPos[square.client.window]) * square.client.area.size.int) div this.dimensionSize().int
          if change != 0:
            square.resize(change)
            resized = true
      this.shuffle(dir.opposite)
  growForSize(pureRequestedSize)
  resized = true
  growForSize(requestedSize)

proc iterDistr(this: PimoLayout, dir: Direction) =
  generalizeForDirection(dir)
  let
    usableWidth = this.monitorArea.width - this.offset.left - this.offset.right
    usableHeight = this.monitorArea.height - this.offset.top - this.offset.bottom
    sortedEdge =
      if towardsStart: this.trackedClients.sortedByIt(it.client.area.startEdge)
      else: this.trackedClients.sortedByIt((if dir == Right: usableWidth else: usableHeight).int - it.client.area.endEdge)
  var
    changed = true
    i = 0
  while changed:
    changed = false
    for square in sortedEdge:
      var
        closestEnd = this.dimensionSize.int + this.offsetTot.int - this.offsetEnd.int
        closestStart = this.offsetStart.int
      for inner in sortedEdge:
        if inner.client.window == square.client.window: continue
        if inner.client.area.sameDir(square.client.area):
          if inner.client.area.endEdge <= square.client.area.startEdge:
            closestStart = max(closestStart, inner.client.area.endEdge)
          else:
            closestEnd = min(closestEnd, inner.client.area.startEdge)
      let
        spaceStart = square.client.area.startEdge - closestStart
        spaceEnd = closestEnd - square.client.area.endEdge
      if towardsEnd and spaceEnd > spaceStart and (spaceEnd - spaceStart) div 2 != 0:
        if horizontal: square.client.area.x += (spaceEnd - spaceStart) div 2
        if vertical: square.client.area.y += (spaceEnd - spaceStart) div 2
        changed = true
      if towardsStart and spaceStart > spaceEnd and (spaceStart - spaceEnd) div 2 != 0:
        if horizontal: square.client.area.x -= (spaceStart - spaceEnd) div 2
        if vertical: square.client.area.y -= (spaceStart - spaceEnd) div 2
        changed = true
    inc i

proc collapse(this: PimoLayout, dir: Direction) =
  this.shuffle(dir)
  var
    monitorArea = this.monitorArea
    bounding = calcBounding(this.trackedClients)
  monitorArea.width -= this.offset.left + this.offset.right
  monitorArea.height -= this.offset.top + this.offset.bottom
  generalizeForDirection(dir)
  if bounding.size > monitorArea.size:
    var oldPos: Table[Window, int]
    for square in this.trackedClients:
      oldPos[square.client.window] = square.client.area.leadingEdge
    this.shuffle(dir.opposite)
    let diff = bounding.size.int - monitorArea.size.int
    for square in this.trackedClients:
      if (oldPos[square.client.window] - square.client.area.leadingEdge) <= diff:
        square.client.area.size = max(0, square.client.area.size.int - diff).uint

proc reDistr(this: PimoLayout, dir: Direction) =
  this.collapse(dir)
  this.shuffle(dir)
  this.iterGrow(dir.opposite)
  this.iterDistr(dir.opposite)

proc reDistr(this: PimoLayout, dir1, dir2: Direction) =
  this.reDistr dir2
  this.reDistr dir1

proc addWindow(this: PimoLayout, s: TrackedClient) =
  proc cmp(x, y: Solution): int =
    # TODO: Take into account movement length for windows
    let
      areaX = x.bounding.area
      areaY = y.bounding.area
    if areaX != areaY:
      return areaX.int - areaY.int
    let
      ratio = (this.monitorArea.width - this.offset.left - this.offset.right).float / (this.monitorArea.height - this.offset.top - this.offset.bottom).float
      ratioX = abs(x.bounding.width.float / x.bounding.height.float - ratio)
      ratioY = abs(y.bounding.width.float / y.bounding.height.float - ratio)
    if ratioX != ratioY:
      return (ratioX - ratioY).int
    let
      xOverlap = x.overlapX + x.overlapY
      yOverlap = y.overlapX + y.overlapY
    if xOverlap != yOverlap:
      return xOverlap - yOverlap
    return x.overlaps.len - y.overlaps.len

  s.client.area = s.requested

  var solutions: seq[Solution]
  let
    backup = this.trackedClients.mapIt(it.client.area)
    sBackup = s.client.area
  template addSolution(d1, d2: Direction): untyped =
    solutions.add this.testSolution(s, d1, d2)
    s.client.area = sBackup
    for i, client in this.trackedClients.mpairs: client.client.area = backup[i]
  addSolution(Left, Up)
  addSolution(Up, Left)
  addSolution(Up, Right)
  addSolution(Right, Up)
  addSolution(Left, Down)
  addSolution(Down, Left)
  addSolution(Down, Right)
  addSolution(Right, Down)
  solutions.sort(cmp)
  let solution = solutions[0]
  #if solution.overlap == 0:
  #this.trackedClients = solution.solution
  for i, client in this.trackedClients.mpairs: client.client.area = solution.solution[i]
  s.client.area = solution.newPosition
  if solution.overlaps.len != 0:
    #echo "Solution has overlaps, solving with new window in position: ", s.client.area
    this.solveConflict(s, solution)
  else:
    this.trackedClients.add s
  this.reDistr(solution.dir1, solution.dir2)
  #for dir in [solution.dir1, solution.dir2]:
  #  case dir:
  #  of Left: this.distribRight()
  #  of Right: this.distribLeft()
  #  of Up: this.distribDown()
  #  of Down: this.distribUp()

proc see(this: PimoLayout, x: TrackedClient, dir: Direction): seq[TrackedClient] =
  this.shuffle(dir)
  generalizeForDirection(dir)
  for square in this.trackedClients:
    if ((towardsStart and x.client.area.startEdge == square.client.area.endEdge)  or
       (towardsEnd and x.client.area.endEdge == square.client.area.startEdge)) and
       x.client.area.sameDir square.client.area:
      result.add square
  this.shuffle(dir.opposite)
  for square in this.trackedClients:
    if ((towardsStart and x.client.area.startEdge == square.client.area.endEdge)  or
       (towardsEnd and x.client.area.endEdge == square.client.area.startEdge)) and
       x.client.area.sameDir square.client.area:
      if square notin result:
        result.add square
  this.iterDistr(dir)

proc insertInStack(this: PimoLayout, x, point: TrackedClient, beginning: bool, stack: seq[TrackedClient], dir: Direction, flipped = false) =
  generalizeForDirection(if flipped: dir else: (if dir in {Right, Left}: Up else: Left))
  # Handle the opposite direction of the stack
  # TODO: Don't go more in the opposite direction than we currently are. If adding to left side don't move right side further away. Then grow in height before growing in width
  if vertical:
    x.client.area.leftEdge = point.client.area.leftEdge
    x.client.area.width = point.client.area.width
  else:
    x.client.area.topEdge = point.client.area.topEdge
    x.client.area.height = point.client.area.height
  # Add next to chosen window in stack
  let ratio = x.client.area.size.float / (x.client.area.size + point.client.area.size).float
  x.client.area.size = (point.client.area.size.float * ratio).int
  for square in stack:
    square.client.area.size = (square.client.area.size.float * (1 - ratio)).int
  #point.size = (point.size.float * (1 - ratio)).cint
  if beginning:
    x.client.area.startEdge = point.client.area.startEdge
    point.client.area.startEdge = point.client.area.startEdge + x.client.area.size.int
    this.reDistr(dir, if dir in {Right, Left}: Down else: Right)
  else:
    x.client.area.startEdge = point.client.area.endEdge
    this.reDistr(dir, if dir in {Right, Left}: Up else: Left)

proc addToStack(this: PimoLayout, x: TrackedClient, stack: seq[TrackedClient], dir: Direction) =
  generalizeForDirection(if dir in {Right, Left}: Up else: Left)
  var
    beginning = true
    point = stack[0]
    minDist = int.high
    xPos = x.client.area.startEdge + x.client.area.size.int div 2
  for square in stack:
    let dist = (square.client.area.startEdge + square.client.area.size.int div 2) - xPos
    if abs(dist) < minDist:
      minDist = abs(dist)
      beginning = dist > 0
      point = square
  this.insertInStack(x, point, beginning, stack, dir)

proc move(this: PimoLayout, x: TrackedClient, dir: Direction) =
  let sees = this.see(x, dir)
  generalizeForDirection(dir)
  case sees.len.uint:
  of 0:
    #echo "Try moving to stack besides it!"
    let
      stackBefore = this.see(x, if horizontal: Up else: Left)
      stackAfter = this.see(x, if horizontal: Down else: Right)
    var beforePoint = x
    for square in stackBefore:
      if beforePoint == x or square.client.area.leadingEdge.before beforePoint.client.area.leadingEdge:
        beforePoint = square
    var afterPoint = x
    for square in stackAfter:
      if afterPoint == x or square.client.area.leadingEdge.before afterPoint.client.area.leadingEdge:
        afterPoint = square
    let
      before = if beforePoint != x and (afterPoint == x or abs(beforePoint.client.area.leadingEdge - x.client.area.trailingEdge) < abs(afterPoint.client.area.leadingEdge - x.client.area.trailingEdge)): true else: false
      point = if before: beforePoint else: afterPoint
    this.insertInStack(x, point, towardsStart, if before: stackBefore else: stackAfter, dir, flipped = true)
    #if (before and stackBefore.len > 1) or (not before and stackAfter.len > 1):
    #  #this.insertInStack(x, point, towardsStart, if before: stackBefore else: stackAfter, dir, flipped = true)
    #  this.addToStack(x, @[point], if before: (if horizontal: Left else: Up) else: (if horizontal: Right else: Down))
    #else:
    #  if before and stackBefore.len == 1:
    #    point.client.area.
    #  #if before:
    #  #  point.client.area.leadingEdge = x.client.area.trailingEdge
    #  #  if direction
    #  #this.addToStack(x, @[point], if before: (if horizontal: Up else: Left) else: (if horizontal: Down else: Right))
    #  discard
  of 1:
    let otherSees = this.see(sees[0], dir.opposite)
    if otherSees.len == 1:
      #echo "Swapping!"
      swap(x.client.area, sees[0].client.area)
      x.client.area.size = min(x.client.area.size, sees[0].client.area.size)
      sees[0].client.area.size = min(x.client.area.size, sees[0].client.area.size)
      if horizontal:
        this.reDistr(dir, Up)
      else:
        this.reDistr(dir, Left)
    else:
      #echo "Create stack!"
      this.addToStack(x, sees, dir)
  of 2..uint.high:
    #echo "Inject into stack!"
    this.addToStack(x, sees, dir)

method newLayout*(settings: PimoLayoutSettings,
    monitorArea: Area,
    borderWidth: uint,
    layoutOffset: LayoutOffset): Layout =
  PimoLayout(
    name: layoutName,
    monitorArea: monitorArea,
    borderWidth: borderWidth,
    offset: layoutOffset,
    settings: settings
  ).Layout

method updateSettings*(
    this: var PimoLayout,
    settings: LayoutSettings,
    monitorArea: Area,
    borderWidth: uint,
    layoutOffset: LayoutOffset) =
  this.settings = settings.PimoLayoutSettings
  this.monitorArea = monitorArea
  this.borderWidth = borderWidth
  this.offset = layoutOffset

method arrange*(this: PimoLayout, display: PDisplay, clients: seq[Client], offset: LayoutOffset) =
  this.offset = offset
  this.offset.left += this.settings.gapSize div 2 + this.settings.outerGap
  this.offset.right += this.settings.gapSize div 2 + this.settings.outerGap
  this.offset.top += this.settings.gapSize div 2 + this.settings.outerGap
  this.offset.bottom += this.settings.gapSize div 2 + this.settings.outerGap

  var
    removedClients = this.trackedClients
    addedClients: seq[TrackedClient]
    stayedClients: seq[TrackedClient]
  for client in clients:
    block clientCheck:
      for i, removed in removedClients:
        if removed.client.window == client.window:
          if not client.isFloating and not client.isFullscreen and not client.isFixedSize:
            removedClients.del(i)
            stayedClients.add(removed)
          break clientCheck
      if not client.isFloating and not client.isFullscreen and not client.isFixedSize:
        addedClients.add TrackedClient(client: client, requested: client.oldArea, expandX: false, expandY: false)
  for client in removedClients:
    this.trackedClients.keepItIf(it.client.window != client.client.window)
    this.reDistr(Up, Left)
  for client in addedClients:
    client.requested.width = min(this.monitorArea.width, client.requested.width + client.client.borderWidth * 2'u + this.settings.gapSize)
    client.requested.height = min(this.monitorArea.height, client.requested.height + client.client.borderWidth * 2'u + this.settings.gapSize)
    this.addWindow(client)

  if addedClients.len == 0 and removedClients.len == 0:
    for client in stayedClients:
      client.client.area.width += client.client.borderWidth * 2'u + this.settings.gapSize
    this.reDistr(Left)
    for client in stayedClients:
      client.client.area.height += client.client.borderWidth * 2'u + this.settings.gapSize
    this.reDistr(Up)

  for client in this.trackedClients:
    client.client.area.x += this.monitorArea.x + client.client.borderWidth.int + this.settings.gapSize.int div 2
    client.client.area.y += this.monitorArea.y + client.client.borderWidth.int + this.settings.gapSize.int div 2
    client.client.area.width -= client.client.borderWidth * 2'u + this.settings.gapSize
    client.client.area.height -= client.client.borderWidth * 2'u + this.settings.gapSize
    client.client.adjustToState(display)

template expand(layout: Layout, tc: TaggedClients, dir: untyped): untyped =
  tc.withSomeCurrClient(client):
    for trackedClient in layout.trackedClients:
      if trackedClient.client.window == client.window:
        trackedClient.client.isFloating = false
        trackedClient.`expand dir` = not trackedClient.`expand dir`
        break

proc expandX(layout: Layout, tc: TaggedClients) =
  var layout = cast[PimoLayout](layout)
  expand(layout, tc, X)

proc expandY(layout: Layout, tc: TaggedClients) =
  var layout = cast[PimoLayout](layout)
  expand(layout, tc, Y)

template grow(layout: Layout, tc: TaggedClients, dir, dim: untyped): untyped =
  tc.withSomeCurrClient(client):
    for trackedClient in layout.trackedClients:
      if trackedClient.client.window == client.window:
        trackedClient.requested.dim = max(trackedClient.client.area.dim, trackedClient.requested.dim)
        trackedClient.requested.dim += layout.settings.resizeStep
        let
          dirForX {.inject.} = [Left, Right]
          dirForY {.inject.} = [Up, Down]
        var seen: seq[TrackedClient]
        for d in `dirFor dir`:
          seen.add layout.see(trackedClient, d)
        generalizeForDirection(`dirFor dir`[0])
        for s in seen:
          s.client.area.size = s.client.area.size - layout.settings.resizeStep
        break

proc growX(layout: Layout, tc: TaggedClients) =
  var layout = cast[PimoLayout](layout)
  grow(layout, tc, x, width)

proc growY(layout: Layout, tc: TaggedClients) =
  var layout = cast[PimoLayout](layout)
  grow(layout, tc, y, height)

template shrink(layout: Layout, tc: TaggedClients, dir, dim: untyped): untyped =
  tc.withSomeCurrClient(client):
    for taggedClient in layout.trackedClients:
      if taggedClient.client.window == client.window:
        if taggedClient.`expand dir`:
          taggedClient.`expand dir` = false
        taggedClient.requested.dim = max(taggedClient.client.area.dim - layout.settings.resizeStep, 100)
        break

proc shrinkX(layout: Layout, tc: TaggedClients) =
  var layout = cast[PimoLayout](layout)
  shrink(layout, tc, x, width)

proc shrinkY(layout: Layout, tc: TaggedClients) =
  var layout = cast[PimoLayout](layout)
  shrink(layout, tc, y, height)

proc move(layout: Layout, tc: TaggedClients, dir: Direction) =
  tc.withSomeCurrClient(client):
    var layout = cast[PimoLayout](layout)
    for taggedClient in layout.trackedClients:
      if taggedClient.client.window == client.window:
        taggedClient.client.isFloating = false
        layout.move(taggedClient, dir)
        break

proc moveRight(layout: Layout, tc: TaggedClients) =
  layout.move(tc, Right)

proc moveLeft(layout: Layout, tc: TaggedClients) =
  layout.move(tc, Left)

proc moveUp(layout: Layout, tc: TaggedClients) =
  layout.move(tc, Up)

proc moveDown(layout: Layout, tc: TaggedClients) =
  layout.move(tc, Down)

proc focus(layout: PimoLayout, dir: Direction, tc: TaggedClients) =
  tc.withSomeCurrClient(client):
    for taggedClient in layout.trackedClients:
      if taggedClient.client.window == client.window:
        let sees = layout.see(taggedClient, dir)
        if sees.len > 0:
          tc.selectClient(sees[0].client.window)
        break

proc focusLeft(layout: Layout, taggedClients: TaggedClients) =
  cast[PimoLayout](layout).focus(Left, taggedClients)

proc focusRight(layout: Layout, taggedClients: TaggedClients) =
  cast[PimoLayout](layout).focus(Right, taggedClients)

proc focusUp(layout: Layout, taggedClients: TaggedClients) =
  cast[PimoLayout](layout).focus(Up, taggedClients)

proc focusDown(layout: Layout, taggedClients: TaggedClients) =
  cast[PimoLayout](layout).focus(Down, taggedClients)

method availableCommands*(this: PimoLayoutSettings): seq[tuple[command: string, action: proc(layout: Layout, taggedClients: TaggedClients) {.nimcall.}]] =
  result = @[
    ($pFocusLeft, focusLeft),
    ($pFocusRight, focusRight),
    ($pFocusUp, focusUp),
    ($pFocusDown, focusDown),
    ($pMoveLeft, moveLeft),
    ($pMoveRight, moveRight),
    ($pMoveUp, moveUp),
    ($pMoveDown, moveDown),
    ($pExpandX, expandX),
    ($pExpandY, expandY),
    ($pGrowX, growX),
    ($pGrowY, growY),
    ($pShrinkX, shrinkX),
    ($pShrinkY, shrinkY)
  ]

method parseLayoutCommand*(this: PimoLayoutSettings, command: string): string =
  try:
    return $parseEnum[Commands](command.toLower)
  except:
    return ""

method populateLayoutSettings*(this: var PimoLayoutSettings, config: TomlTableRef) =
  if config == nil:
    this.gapSize = 12
    this.resizeStep = 10
    this.outerGap = 0
    return
  if config.hasKey("gapSize"):
    let gapSizeSetting = config["gapSize"]
    if gapSizeSetting.kind == TomlValueKind.Int:
      this.gapSize = max(0, gapSizeSetting.intVal).uint
    else:
      log "gapSize is not an integer value!", lvlWarn
  if config.hasKey("resizeStep"):
    let resizeStepSetting = config["resizeStep"]
    if resizeStepSetting.kind == TomlValueKind.Int:
      this.resizeStep = max(0, resizeStepSetting.intVal).uint
    else:
      log "resizeStep is not an integer value!", lvlWarn
  if config.hasKey("outerGap"):
    let outerGapSetting = config["outerGap"]
    if outerGapSetting.kind == TomlValueKind.Int:
      this.outerGap = max(0, outerGapSetting.intVal).uint
    else:
      log "outerGap is not an integer value!", lvlWarn
