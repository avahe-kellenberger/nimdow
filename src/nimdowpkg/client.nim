import
  x11 / [x, xlib],
  hashes,
  area

type
  Client* = ref object of RootObj
    window*: Window
    x*: int
    y*: int
    width*: uint
    height*: uint
    borderWidth*: uint
    isFullscreen*: bool
    isFloating*: bool
    isFixed*: bool

proc hash*(this: Client): Hash

proc newClient*(window: Window): Client =
  Client(window: window)

proc adjustToState*(this: Client, display: PDisplay) =
  ## Changes the client's location, size, and border based on the client's internal state.
  discard XMoveResizeWindow(
    display,
    this.window,
    this.x.cint,
    this.y.cint,
    this.width.cuint,
    this.height.cuint
  )
  discard XSetWindowBorderWidth(display, this.window, this.borderWidth.cuint)

  var windowChanges: XWindowChanges
  windowChanges.x = this.x.cint
  windowChanges.y = this.y.cint
  windowChanges.width = this.width.cint
  windowChanges.height = this.height.cint
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

proc toArea*(this: Client): Area = (this.x, this.y, this.width, this.height)

proc hash*(this: Client): Hash = !$Hash(this.window) 
