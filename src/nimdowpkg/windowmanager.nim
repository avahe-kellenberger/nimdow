import
  x11 / [x, xlib, xutil, xatom],
  math,
  strformat

import
  Xproto,
  xatoms,
  drw

converter intToFloat(x: int): float = x.float
converter intToCint(x: int): cint = x.cint
converter intToCUint(x: int): cuint = x.cuint
converter cintToUint(x: cint): uint = x.uint
converter cintToCUint(x: cint): cuint = x.cuint
converter intToCUchar(x: int): cuchar = x.cuchar
converter clongToCUlong(x: clong): culong = x.culong
converter toXBool(x: bool): XBool = x.XBool
converter toBool(x: XBool): bool = x.bool

# NOTES: 0 in C is false, all other ints are true.

const
  WM_NAMO = "nimdow"
  MIN_UPDATE_INTERVAL = math.round(1000 / 60).int
  BROKEN = "<No Name>"
  TAG_COUNT = 9
  TAGS = [ "1", "2", "3", "4", "5", "6", "7", "8", "9" ]
  MODKEY = Mod4Mask

const
  colorBorder: uint = 0

type Click = enum
  ClkTagBar, ClkLtSymbol, ClkStatusText, ClkWinTitle,
  ClkClientWin, ClkRootWin, ClkLast

type
  Monitor = ref object of RootObj
    screenX, screenY, screenWidth, screenHeight: int
    layoutSymbol: string
    # Scale between left and right of screen. Need a better name.
    mFactor: float
    numMasterWindows: int
    # Monitor index?
    num: int
    barY: int
    windowAreaX, windowAreaY, windowAreaWidth, windowAreaHeight: int
    gapInnerHorizontal, gapInnerVertical: int
    gapOuterHorizontal, gapOuterVertical: int
    selectedTags: uint
    selectedLayout: uint
    tagset: array[2, uint]
    showBar, topBar: bool
    # Singlar client because they are linked internally
    clients: Client
    selectedClient: Client
    clientStack: Client
    next: Monitor
    bar: Window
    layout: Layout
    pertag: Pertag

  Client = ref object of RootObj
    x, y, width, height: int
    next: Client
    stackNext: Client
    monitor: Monitor
    window: Window
    tags: uint
    borderWidth, oldBorderWidth: uint
    minAspectRatio, maxAspectRatio: float
    # Dimensions
    baseWidth, baseHeight: int
    minWidth, minHeight: int
    maxWidth, maxHeight: int
    # Increment, I think
    incWidth, incHeight: int
    isFixed, isCentered,
      isFloating, isUrgent,
      neverFocus, isFullscreen,
      needsResize: bool
    oldState: int

  Layout = ref object of RootObj

  Pertag = ref object of RootObj
    currentTag, previousTag: uint
    numMasterWindows: array[TAG_COUNT, int]
    mFactors: array[TAG_COUNT, float]
    selectedLayouts: array[TAG_COUNT, uint]
    showBars: array[TAG_COUNT, bool]

  Button = object
    click: Click
    eventMask: int
    # Button1, Button2, ...ButtonN
    button: int
    callback: proc()

# Function declarations
proc applyRules(client: var Client)
proc applySizeHints(client: Client, x, y, width, height: var int, interact: bool): bool
proc arrange(monitor: var Monitor)
proc arrangeMonitor(monitor: Monitor)
proc attach(client: var Client)
proc attachBelow(client: var Client)
proc attachStack(client: var Client)
proc buttonPress(e: XEvent)
proc checkOtherWM()
proc cleanup()

proc focus(client: var Client)
proc getRootPointer(x, y: ptr int): bool
proc grabButtons(client: Client, focused: bool)
proc intersect(monitor: Monitor, x, y, width, height: int): int
proc isVisible(client: Client): bool
proc moveMouse()
proc rectToMonitor(x, y, width, height: int): Monitor
proc restack(monitor: Monitor)
proc showhide(client: Client)
proc textWidth(str: string): uint
proc unfocus(client: Client, setFocus: bool)
proc windowToClient(window: Window): Client
proc windowToMonitor(window: Window): Monitor
proc xError(display: PDisplay, event: PXErrorEvent): cint {.cdecl}
proc xErrorStart(display: PDisplay, e: PXErrorEvent): cint {.cdecl}

var
  display: PDisplay
  sText: string # ?
  screen: int
  screenWidth, screenHeight: int
  barHeight, barWidth: int = 0
  enableGaps: bool = true
  lrpad: uint # sum of left and right padding for text
  numlockMask: uint = 0
  running: bool = true
  monitors, selectedMonitor: Monitor
  root, wmCheckWindow: Window
  useARGB: bool = false
  visual: PVisual
  depth: int
  colormap: Colormap
  # TODO: Better name?
  draw: Drw = newDrw(display, root)
  xErrorHandler: XErrorHandler

# config.h vars
var
  respectResizeHints: bool = false
  # Button defs
  buttons: array[1, Button] =
    [
      Button(click: ClkClientWin, eventMask: MODKEY, button: Button1, callback: movemouse)
    ]

# TODO: Need to invoke xatoms.initAtoms

template cleanMask(mask: uint): uint =
  (mask and not(numlockMask or LockMask)) and
  (ShiftMask or ControlMask or Mod1Mask or Mod2Mask or Mod3Mask or Mod4Mask or Mod5Mask)

template NIL[T](): var T =
  var dummyT: T
  dummyT

proc applyRules(client: var Client) =
  # We don't care about dwm rules currently
  discard

proc applySizeHints(client: Client, x, y, width, height: var int, interact: bool): bool =
  var
    baseIsMin: bool
    monitor: Monitor = client.monitor
  # Set minimum possible
  width = max(1, width)
  height = max(1, height)

  if interact:
    if x > screenWidth:
      x = screenWidth - client.width
    if y > screenHeight:
      y = screenHeight - client.height
    if (x + width + 2 * client.borderWidth) < 0:
      x = 0
    if (y + height + 2 * client.borderWidth) < 0:
      y = 0
  else:
    if x >= (monitor.windowAreaX + monitor.windowAreaWidth):
      x = monitor.windowAreaX + monitor.windowAreaWidth - client.width
    if y >= (monitor.windowAreaY + monitor.windowAreaHeight):
      y = monitor.windowAreaY + monitor.windowAreaHeight - client.height
    if (x + width + 2 * client.borderWidth) <= monitor.windowAreaX:
      x = monitor.windowAreaX
    if (y + height + 2 * client.borderWidth) <= monitor.windowAreaY:
      y = monitor.windowAreaY

  # TODO: Why?
  if height < barHeight:
    height = barHeight
  if width < barHeight:
    width = barHeight

  if respectResizeHints or client.isFloating:
    baseIsMin = client.baseWidth == client.minWidth and client.baseHeight == client.minHeight

    if not baseIsMin:
      width.dec(client.baseWidth)
      height.dec(client.baseHeight)

    # Adjust for aspect limits
    if client.minAspectRatio > 0 and client.maxAspectRatio > 0:
      if client.maxAspectRatio < (width / height):
        width = (height * client.maxAspectRatio + 0.5).int
      elif client.minAspectRatio < (height / width):
        height = (width * client.minAspectRatio + 0.5).int

    # Increment calculation requires this
    if baseIsMin:
      width.dec(client.baseWidth)
      height.dec(client.baseHeight)

    # Adjust for increment value
    if client.incWidth != 0:
      width -= width mod client.incWidth
    if client.incHeight != 0:
      height -= height mod client.incHeight

    # Restore base dimenons
    width = max(width + client.baseWidth, client.minWidth)
    height = max(height + client.baseHeight, client.minHeight)
    if client.maxWidth != 0:
      width = min(width, client.maxWidth)
    if client.maxHeight != 0:
      height = min(height, client.maxHeight)

    return x != client.x or
           y != client.y or
           width != client.width or
           height != client.height

proc arrange(monitor: var Monitor) =
  if monitor != nil:
    showhide(monitor.clientStack)
  else:
    monitor = monitors
    while monitor != nil:
      showhide(monitor.clientStack)
      monitor = monitor.next

  if monitor != nil:
    arrangeMonitor(monitor)
    restack(monitor)
  else:
    monitor = monitors
    while monitor != nil:
      arrangeMonitor(monitor)
      monitor = monitor.next

# TODO: Figure out a nice layout system.
method arrange(this: Layout) {.base.} =
  echo "Not implemented for base class"

proc arrangeMonitor(monitor: Monitor) =
  monitor.layout.arrange()

proc attach(client: var Client) =
  client.next = client.monitor.clients
  client.monitor.clients = client

proc attachBelow(client: var Client) =
  var below = client.monitor.clients

  while below != nil and below.next != nil:
    below = below.next

  if below != nil:
    below.next = client
  else:
    client.monitor.clients = client

proc attachStack(client: var Client) =
  client.stackNext = client.monitor.clientStack
  client.monitor.clientStack = client

proc buttonPress(e: XEvent) =
  var
    client: Client
    monitor: Monitor
    event = e.xbutton
    click = ClkRootWin

  # Focus monitor if necessary
  monitor = windowToMonitor(event.window)
  if monitor != nil and monitor != selectedMonitor:
    unfocus(selectedMonitor.selectedClient, true)
    selectedMonitor = monitor
    focus(NIL[Client])

  client = windowToClient(event.window)
  if client != nil:
    focus(client)
    restack(selectedMonitor)
    discard XAllowEvents(display, ReplayPointer, CurrentTime)
    click = ClkClientWin

  for button in buttons:
    if button.button == event.button and
       cleanMask(button.eventMask) == cleanMask(event.state):
         button.callback()

proc checkOtherWM() =
  xErrorHandler = XSetErrorHandler(xErrorStart)
  # This causes an error if some other window manager is running
  discard XSelectInput(display, DefaultRootWindow(display), SubstructureRedirectMask)
  discard XSync(display, false)
  discard XSetErrorHandler(xError)
  discard XSync(display, false)

proc cleanup() =
  discard

proc focus(client: var Client) =
  if client == nil or not client.isVisible():
    client = selectedMonitor.clientStack
    while client != nil and not client.isVisible():
      client = client.stackNext

proc intersect(monitor: Monitor, x, y, width, height: int): int =
  ## Gets the intersection if the two rects.
  # TODO: Rename this after all the code has been ported.
  let
    xIntersection =
      max(0,
        # min of right side of both rects
        min(x + width, monitor.windowAreaX + monitor.windowAreaWidth) -
        # max of left side of both rects
        max(x, monitor.windowAreaX)
      )
    yIntersection =
      max(0,
        min(y + height, monitor.windowAreaY + monitor.windowAreaHeight) -
        max(y, monitor.windowAreaY)
      )

  return xIntersection * yIntersection

proc getRootPointer(x, y: ptr int): bool =
  var
    di: int
    dui: uint
    dummy: Window
  let res = XQueryPointer(
    display,
    root,
    dummy.addr,
    dummy.addr,
    cast[Pcint](x),
    cast[Pcint](y),
    cast[Pcint](di.addr),
    cast[Pcint](di.addr),
    cast[Pcuint](dui.addr)
  )
  return res != 0

proc grabButtons(client: Client, focused: bool) =
  discard

proc isVisible(client: Client): bool =
  let mask = client.tags and client.monitor.tagset[client.monitor.selectedTags]
  return mask != 0

proc moveMouse() =
  discard

proc rectToMonitor(x, y, width, height: int): Monitor =
  result = selectedMonitor
  var
    monitor = selectedMonitor
    a, area: int

  while monitor != nil:
    a = monitor.intersect(x, y, width, height)
    if a > area:
      area = a
      result = monitor
    monitor = monitor.next

proc restack(monitor: Monitor) =
  discard

proc showhide(client: Client) =
  discard

proc textWidth(str: string): uint =
  draw.fontsetGetWidth(str) + lrpad

proc unfocus(client: Client, setFocus: bool) =
  if client == nil:
    return
  grabButtons(client, false)
  discard XSetWindowBorder(
    display,
    client.window,
    colorBorder
  )

  if setFocus:
    discard XSetInputFocus(
      display,
      root,
      RevertToPointerRoot,
      CurrentTime
    )
    discard XDeleteProperty(
      display,
      root,
      $NetActiveWindow
    )

proc windowToClient(window: Window): Client =
  var
    client: Client
    monitor: Monitor = monitors

  while monitor != nil:
    client = monitor.clients
    while client != nil:
      if client.window == window:
        return client
      client = client.next
    monitor = monitor.next
  return nil

proc windowToMonitor(window: Window): Monitor =
  var
    x, y: int
    client: Client
    monitor: Monitor

  if window == root and getRootPointer(x.addr, y.addr):
    return rectToMonitor(x, y, 1, 1)

  monitor = monitors
  while monitor != nil:
    if window == monitor.bar:
      return monitor
    monitor = monitor.next

  client = windowToClient(window)
  if client != nil:
    return client.monitor

  return selectedMonitor

proc xError(display: PDisplay, event: PXErrorEvent): cint {.cdecl} =
  ## There's no way to check accesses to destroyed windows, thus those cases are
  ## ignored (especially on UnmapNotify's). Other types of errors call Xlibs
  ## default error handler, which may call exit.
  if event.error_code == BadWindow or
     event.request_code == XProtoSetInputFocus and event.error_code == BadMatch or
     event.request_code == XProtoPolyText8 and event.error_code == BadDrawable or
     event.request_code == XProtoPolyFillRectangle and event.error_code == BadDrawable or
     event.request_code == XProtoPolySegment and event.error_code == BadDrawable or
     event.request_code == XProtoConfigureWindow and event.error_code == BadMatch or
     event.request_code == XProtoGrabButton and event.error_code == BadAccess or
     event.request_code == XProtoGrabKey and event.error_code == BadAccess or
     event.request_code == XProtoCopyArea and event.error_code == BadDrawable:
    return 0
  echo fmt("nimdow: fatal error: request_code={event.request_code}, error_code={event.error_code}")
  return xErrorHandler(display, event)

proc xErrorStart(display: PDisplay, e: PXErrorEvent): cint {.cdecl} =
  quit("nimdow: another window manager is already running", 1)

