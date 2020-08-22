import
  x11 / [x, xlib],
  hashes,
  area,
  xatoms

converter intToCint(x: int): cint = x.cint
converter uintToCint(x: uint): cint = x.cint
converter toXBool(x: bool): XBool = x.XBool

type
  Client* = ref object of RootObj
    window*: Window
    area*: Area
    oldArea*: Area
    borderWidth*: uint
    oldBorderWidth*: uint
    isFullscreen*: bool
    isFloating*: bool
    oldFloatingState*: bool
    # Non-resizable
    isFixed*: bool
    needsResize*: bool

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

proc configure*(this: Client, display: PDisplay) =
  var event: XConfigureEvent
  event.theType = ConfigureNotify
  event.display = display
  event.event = this.window
  event.window = this.window
  event.x = this.x
  event.y = this.y
  event.width = this.width
  event.height = this.height
  event.border_width = this.borderWidth
  event.above = None
  event.override_redirect = 0
  discard XSendEvent(
    display,
    this.window,
    0,
    StructureNotifyMask,
    cast[PXEvent](event.addr)
  )

proc adjustToState*(this: Client, display: PDisplay) =
  ## Changes the client's location, size, and border based on the client's internal state.
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
  this.configure(display)
  discard XSync(display, false)

proc resize*(this: Client, display: PDisplay, x, y: int, width, height: uint) =
  ## Resizes and raises the client.
  this.oldX = this.x
  this.x = x

  this.oldY = this.y
  this.y = y

  this.oldWidth = this.width
  this.width = width

  this.oldHeight = this.height
  this.height = height

  this.adjustToState(display)
  # discard XRaiseWindow(display, this.window)

proc show*(this: Client, display: PDisplay) =
  ## Moves the client to its current geom.
  if this.needsResize:
    this.needsResize = false
    discard XMoveResizeWindow(
      display,
      this.window,
      this.x,
      this.y,
      this.width.cuint,
      this.height.cuint
    )
  else:
    discard XMoveWindow(
      display,
      this.window,
      this.x,
      this.y
    )

proc hide*(this: Client, display: PDisplay) =
  ## Moves the client off screen.
  discard XMoveWindow(
    display,
    this.window,
    (this.width.int + this.borderWidth.int * 2) * -2,
    this.y
  )

proc takeFocus*(this: Client, display: PDisplay) =
  discard display.sendEvent(
    this.window,
    $WMTakeFocus,
    NoEventMask,
    ($WMTakeFocus).clong,
    CurrentTime,
    0, 0, 0
  )

proc warpTo*(display: PDisplay, client: Client) =
  discard XWarpPointer(
    display,
    x.None,
    client.window,
    0,
    0,
    0,
    0,
    client.width.int div 2,
    client.height.int div 2
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

