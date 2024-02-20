import
  x11 / [x, xlib],
  parsetoml,
  strutils,
  sequtils,
  math,
  layout,
  ../client,
  ../area,
  ../logger,
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
  PimoLayoutSettings* = ref object of LayoutSettings
    gapSize*: uint
    outerGap*: uint
    resizeStep*: uint
    numMasterWindows*: uint
    defaultMasterWidthPercentage*: int
  Commands = enum
    mscIncreaseMasterCount = "increasemastercount",
    mscDecreaseMasterCount = "decreasemastercount",
    mscIncreaseMasterWidth = "increasemasterwidth",
    mscDecreaseMasterWidth = "decreasemasterwidth",

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
      if towardsStart: this.offsetStart.int
      else: limit.int - square.size.int + this.offsetEnd.int
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
    if horizontal:
      square.client.area.width += change.uint
      if towardsEnd: square.client.area.x -= change
    if vertical:
      square.client.area.height += change.uint
      if towardsEnd: square.client.area.y -= change
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
      else: this.trackedClients.sortedByIt((if dir == Right: usableWidth else: usableHeight).int - it.client.area.endEdge)
  # TODO; Scale down previously expanded windows as well
  for square in this.trackedClients:
    if (horizontal and square.expandX) or (vertical and square.expandY):
      #stdout.writeLine "Resizing ", square, " from ", square.size
      square.resize(min(0, square.pureRequestedSize.int - square.client.area.size.int))
  var resized = true
  while resized:
    resized = false
    var oldPos: Table[Window, int]
    for square in sortedEdge:
      if square.requestedSize < square.client.area.size:
        resized = true
        square.resize(square.requestedSize.int - square.client.area.size.int)
      oldPos[square.client.window] = square.client.area.leadingEdge
    this.shuffle(dir)
    for square in sortedEdge:
      if square.requestedSize != square.client.area.size:
        let change = (abs(square.client.area.leadingEdge - oldPos[square.client.window]) * square.client.area.size.int) div this.dimensionSize().int
        if change != 0:
          square.resize(change)
          resized = true
    this.shuffle(dir.opposite)

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
        closestEnd = this.dimensionSize.int
        closestStart = 0
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

proc distribLeft(this: PimoLayout) =
  this.iterGrow(Left)
  this.iterDistr(Left)

proc distribUp(this: PimoLayout) =
  this.iterGrow(Up)
  this.iterDistr(Up)

proc distribRight(this: PimoLayout) =
  this.iterGrow(Right)
  this.iterDistr(Right)

proc distribDown(this: PimoLayout) =
  this.iterGrow(Down)
  this.iterDistr(Down)

proc addWindow(this: PimoLayout, s: TrackedClient) =
  proc cmp(x, y: Solution): int =
    # TODO: Take into account movement length for windows
    let
      areaX = x.bounding.area
      areaY = y.bounding.area
    if areaX != areaY:
      return (areaX - areaY).int
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

  #s.client.area = s.requested
  s.requested = s.client.area
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
    echo "Solution has overlaps, solving with new window in position: ", s.client.area
    this.solveConflict(s, solution)
  else:
    this.trackedClients.add s
  for dir in [solution.dir1, solution.dir2]:
    case dir:
    of Left: this.distribRight()
    of Right: this.distribLeft()
    of Up: this.distribDown()
    of Down: this.distribUp()

method newLayout*(settings: PimoLayoutSettings,
    monitorArea: Area,
    borderWidth: uint,
    layoutOffset: LayoutOffset): Layout =
  PimoLayout(
    name: layoutName,
    monitorArea: monitorArea,
    borderWidth: borderWidth,
    offset: layoutOffset
  ).Layout

method updateSettings*(
  this: var PimoLayout,
  settings: LayoutSettings,
  monitorArea: Area,
  borderWidth: uint,
  layoutOffset: LayoutOffset) =
  echo "Updating PiMo layout settings"

method arrange*(this: PimoLayout, display: PDisplay, clients: seq[Client], offset: LayoutOffset) =
  echo "Arranging by PiMo layout"
  this.offset = offset
  var
    removedClients = this.trackedClients
    addedClients: seq[TrackedClient]
  for client in clients:
    echo client.repr
    block clientCheck:
      for i, removed in removedClients:
        if removed.client.window == client.window:
          removedClients.del(i)
          break clientCheck
      addedClients.add TrackedClient(client: client, requested: client.oldArea, expandX: false, expandY: false)
  echo "Clients removed: ", removedClients.len
  echo "Clients added: ", addedClients.len
  for client in addedClients:
    #this.trackedClients.add client
    this.addWindow(client)
  #this.shuffle(Down, Right)
  for client in this.trackedClients:
    client.client.adjustToState(display)
    echo client.repr

method availableCommands*(this: PimoLayoutSettings): seq[tuple[command: string, action: proc(layout: Layout) {.nimcall.}]] =
  echo "Reporting available commands"
  result = @[
  ]

method parseLayoutCommand*(this: PimoLayoutSettings, command: string): string =
  echo "Parsing layout commands"
  return ""
  try:
    return $parseEnum[Commands](command.toLower)
  except:
    return ""

method populateLayoutSettings*(this: var PimoLayoutSettings, config: TomlTableRef) =
  echo "Populating PiMo layout settings"
  discard
