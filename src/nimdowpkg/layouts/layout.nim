import
  x11 / [x, xlib],
  tables,
  "../client"

type
  Layout* = ref object of RootObj
    name*: string
    gapSize*: uint
    borderWidth*: uint
  LayoutOffset* = tuple[top, left, bottom, right: uint]

proc newLayout*(name: string, gapSize: uint, borderWidth: uint): Layout =
  Layout(name: name, gapSize: gapSize, borderWidth: borderWidth)

method arrange*(this: Layout, display: PDisplay, clients: seq[Client], offset: LayoutOffset) {.base.} =
  echo "Not implemented for base class"

proc calcLayoutOffset(dock: Dock, screenWidth, screenHeight: float): LayoutOffset =
  let dockRatio = dock.width.float / dock.height.float
  let screenRatio = screenWidth / screenHeight

  var offset: LayoutOffset
  if dockRatio > screenRatio:
    # Top or bottom
    let dockYCenter = dock.y.float + (dock.height.float / 2)
    let screenYCenter = screenHeight / 2
    if dockYCenter < screenYCenter:
      # Top
      offset.top = max(0, dock.y + dock.height.int).uint
    else:
      # Bottom
      offset.bottom = max(0, screenHeight.int - dock.y).uint
  else:
    let dockXCenter = dock.x.float + (dock.width.float / 2)
    let screenXCenter = screenWidth / 2
    if dockXCenter < screenXCenter:
      # Left
      offset.left = max(0, dock.x + dock.width.int).uint
    else:
      # Right
      offset.right = max(0, screenWidth.int - dock.x).uint
  return offset

proc calcLayoutOffset*(docks: Table[TWindow, Dock], screenWidth, screenHeight: uint): LayoutOffset =
  var top, left, bottom, right: uint
  for dock in docks.values:
    let offset = calcLayoutOffset(dock, screenWidth.float, screenHeight.float)
    top = max(offset.top, top)
    left = max(offset.left, left)
    bottom = max(offset.bottom, bottom)
    right = max(offset.right, right)
  return (top, left, bottom, right)

