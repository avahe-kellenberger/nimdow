import
  x11 / [x, xlib],
  hashes,
  area

converter intToCint(x: int): cint = x.cint
converter uintToCint(x: uint): cint = x.cint
converter uintToCUint(x: uint): cuint = x.cuint

type
  Client* = ref object of RootObj
    window*: Window
    area*: Area
    oldArea*: Area
    borderWidth*: uint
    oldBorderWidth*: uint
    isFullscreen*: bool
    isFloating*: bool
    # Non-resizable
    isFixed*: bool

proc hash*(this: Client): Hash

proc newClient*(window: Window): Client =
  Client(window: window)

# Area helper procs
proc x*(this: Client): int = this.area.x
proc `x=`*(this: Client, x: int) {.inline.} = this.area.x = x
proc y*(this: Client): int = this.area.y
proc `y=`*(this: Client, y: int) {.inline.} = this.area.y = y
proc width*(this: Client): uint = this.area.width
proc `width=`*(this: Client, width: uint) {.inline.} = this.area.width = width
proc height*(this: Client): uint = this.area.height
proc `height=`*(this: Client, height: uint) {.inline.} = this.area.height = height

# Old area helper procs
proc oldX*(this: Client): int = this.oldArea.x
proc `oldx=`*(this: Client, x: int) {.inline.} = this.oldArea.x = x
proc oldY*(this: Client): int = this.oldArea.y
proc `oldy=`*(this: Client, y: int) {.inline.} = this.oldArea.y = y
proc oldWidth*(this: Client): uint = this.oldArea.width
proc `oldwidth=`*(this: Client, width: uint) {.inline.} = this.oldArea.width = width
proc oldHeight*(this: Client): uint = this.oldArea.height
proc `oldheight=`*(this: Client, height: uint) {.inline.} = this.oldArea.height = height

proc adjustToState*(this: Client, display: PDisplay) =
  ## Changes the client's location, size, and border based on the client's internal state.
  discard XMoveResizeWindow(
    display,
    this.window,
    this.area.x,
    this.area.y,
    this.area.width,
    this.area.height
  )
  discard XSetWindowBorderWidth(display, this.window, this.borderWidth.cuint)

  var windowChanges: XWindowChanges
  windowChanges.x = this.area.x
  windowChanges.y = this.area.y
  windowChanges.width = this.area.width
  windowChanges.height = this.area.height
  windowChanges.border_width = this.borderWidth.cint
  discard XConfigureWindow(
    display,
    this.window,
    CWX or CWY or CWWidth or CWHeight or CWBorderWidth,
    windowChanges.addr
  )

proc isNormal*(this: Client): bool =
  ## If the client is "normal".
  ## This currently means the client is not fixed.
  not this.isFixed

func find*[T](clients: openArray[T], window: Window): int =
  ## Finds a Client's index by its relative window.
  ## If a client is not found, -1 is returned.
  for i, client in clients:
    if client.window == window:
      return i
  return -1

proc findNextNormal*(clients: openArray[Client], i: int = 0): int =
  ## Finds the next normal client index from index `i` (exclusive), iterating forward.
  ## This search will loop the array.
  for j in countup(i + 1, clients.high):
    if clients[j].isNormal:
      return j
  for j in countup(clients.low, i - 1):
    if clients[j].isNormal:
      return j
  return -1

proc findPreviousNormal*(clients: openArray[Client], i: int = 0): int =
  ## Finds the next normal client index from index `i` (exclusive), iterating backward.
  ## This search will loop the array.
  for j in countdown(i - 1, clients.low):
    if clients[j].isNormal:
      return j
  for j in countdown(clients.high, i + 1):
    if clients[j].isNormal:
      return j
  return -1

proc hash*(this: Client): Hash = !$Hash(this.window)

