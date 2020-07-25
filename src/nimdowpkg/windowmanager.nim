import
  x11 / [x, xlib, xutil, xatom, xft],
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
  SYSTEM_TRAY_REQUEST_DOCK = 0
  # XEMBED messages
  XEMBED_EMBEDDED_NOTIFY = 0
  XEMBED_WINDOW_ACTIVATE = 1
  XEMBED_FOCUS_IN = 4
  XEMBED_MODALITY_ON = 10
  # TODO: This different for cint?
  XEMBED_MAPPED = 1 shl 0
  XEMBED_WINDOW_ACTIVATE = 1
  XEMBED_WINDOW_DEACTIVATE = 2
  VERSION_MAJOR = 0
  VERSION_MINOR = 0
  XEMBED_EMBEDDED_VERSION = (VERSION_MAJOR shl 16) or VERSION_MINOR

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
    oldX, oldY, oldWidth, oldHeight: int
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

  Systray = object
    window: Window
    icons: Client

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
proc cleanupMonitor(monitor: var Monitor)
proc clientMessage(e: PXEvent)
proc configure(client: Client)

proc focus(client: var Client)
proc getRootPointer(x, y: ptr int): bool
proc grabButtons(client: Client, focused: bool)
proc intersect(monitor: Monitor, x, y, width, height: int): int
proc isVisible(client: Client): bool
proc moveMouse()
proc rectToMonitor(x, y, width, height: int): Monitor
proc resizeBar(monitor: Monitor)
proc restack(monitor: Monitor)
proc sendEvent(
  window: Window,
  atom: Atom,
  mask: int,
  data0: clong,
  data1: clong,
  data2: clong,
  data3: clong,
  data4: clong
): bool
proc setClientState(client: Client, state: int)
proc setFullscreen(client: Client, shouldFullscreen: bool)
proc setUrgent(client: Client, shouldBeUrgent: bool)
proc showhide(client: Client)
proc textWidth(str: string): uint
proc unfocus(client: Client, setFocus: bool)
proc unmanage(client: Client, destroyed: bool)
proc updateSizeHints(client: Client)
proc updateSystray()
proc updateSystrayIconGeom(client: Client, width, height: int)
proc view(ui: cuint)
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
  systray: Systray
  useARGB: bool = false
  visual: PVisual
  depth: int
  colormap: Colormap
  # TODO: Better name?
  draw: Drw = newDrw(display, root)
  xErrorHandler: XErrorHandler
  backgroundColor: XftColor

# config.h vars
var
  respectResizeHints: bool = false
  showSystray: bool = true
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
  var monitor: Monitor = monitors

  view(cuint.high)
  selectedMonitor.layout = nil

  while monitor != nil:
    while monitor.clientStack != nil:
      unmanage(monitor.clientStack, false)
    monitor = monitor.next

  discard XUngrabKey(display, AnyKey, AnyModifier, root)

  while monitors != nil:
    cleanupMonitor(monitors)

  if showSystray:
    discard XUnmapWindow(display, systray.window)
    discard XDestroyWindow(display, systray.window)

  discard XDestroyWindow(display, wmCheckWindow)
  discard XSync(display, false)
  discard XSetInputFocus(display, PointerRoot, RevertToPointerRoot, CurrentTime)
  discard XDeleteProperty(display, root, $NetActiveWindow)

proc cleanupMonitor(monitor: var Monitor) =
  if monitor == monitors:
    monitors = monitors.next
  else:
    var m: Monitor = monitors

    while m != nil and m.next != monitor:
      m = monitor.next
    m.next = monitor.next

  discard XUnmapWindow(display, monitor.bar)
  discard XDestroyWindow(display, monitor.bar)

proc clientMessage(e: PXEvent) =
  let
    event: XClientMessageEvent = e.xclient

  var
    client: Client = windowToClient(event.window)
    winAttr: XWindowAttributes
    setWinAttr: XSetWindowAttributes

  if showSystray and
     event.window == systray.window and
     event.message_type == $NetSystemTrayOP:
    # Add systray icons
    if event.data.l[1] == SYSTEM_TRAY_REQUEST_DOCK:
      client.window = event.data.l[2]
      if client.window == 0:
        return
      client.monitor = selectedMonitor
      client.next = systray.icons
      systray.icons = client
      discard XGetWindowAttributes(display, client.window, winAttr.addr)
      client.width = winAttr.width
      client.oldWidth = client.width
      client.height = winAttr.height
      client.oldHeight = client.height
      client.oldBorderWidth = winAttr.border_width
      client.borderWidth = 0
      client.isFloating = true
      # Reuse tags field as mapped status
      client.tags = 1
      updateSizeHints(client)
      updateSystrayIconGeom(client, client.width, client.height)
      discard XAddToSaveSet(display, client.window)
      discard XSelectInput(
        display,
        client.window,
        StructureNotifyMask or PropertyChangeMask or ResizeRedirectMask
      )
      discard XReparentWindow(display, client.window, systray.window, 0, 0)
      # Use parent's background color
      setWinAttr.background_pixel = backgroundColor.pixel
      discard XChangeWindowAttributes(
        display,
        client.window,
        CWBackPixel,
        setWinAttr.addr
      )
      discard sendEvent(
        client.window,
        $Xembed,
        StructureNotifyMask,
        CurrentTime,
        XEMBED_EMBEDDED_NOTIFY,
        0,
        systray.window.clong,
        XEMBED_EMBEDDED_VERSION
      )
      # FIXME not sure if I have to send these events, too
      discard sendevent(
        client.window,
        $Xembed,
        StructureNotifyMask,
        CurrentTime,
        XEMBED_FOCUS_IN,
        0,
        systray.window.clong,
        XEMBED_EMBEDDED_VERSION
      )
      discard sendevent(
        client.window,
        $Xembed,
        StructureNotifyMask,
        CurrentTime,
        XEMBED_WINDOW_ACTIVATE,
        0,
        systray.window.clong,
        XEMBED_EMBEDDED_VERSION
      )
      discard sendevent(
        client.window,
        $Xembed,
        StructureNotifyMask,
        CurrentTime,
        XEMBED_MODALITY_ON,
        0,
        systray.window.clong,
        XEMBED_EMBEDDED_VERSION
      )
      discard XSync(display, false)
      resizeBar(selectedMonitor)
      updateSystray()
      setClientState(client, NormalState)
    return

  if client == nil:
    return

  if event.message_type == $NetWMState:
    if event.data.l[1] == $NetWMStateFullScreen or
       event.data.l[2] == $NetWMStateFullScreen:
      let shouldFullscreen =
        # _NET_WM_STATE_ADD
        event.data.l[0] == 1  or
        # _NET_WM_STATE_TOGGLE
        event.data.l[0] == 2 and not client.isFullscreen
      setFullscreen(client, shouldFullscreen)
  elif event.message_type == $NetActiveWindow:
    if client != selectedMonitor.selectedClient and not client.isUrgent:
      setUrgent(client, true)

proc configure(client: Client) =
  var event: XConfigureEvent
  # TODO

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
    maxArea, area: int

  while monitor != nil:
    maxArea = monitor.intersect(x, y, width, height)
    if maxArea > area:
      area = maxArea
      result = monitor
    monitor = monitor.next

proc resizeBar(monitor: Monitor) =
  discard

proc restack(monitor: Monitor) =
  discard

proc sendEvent(
  window: Window,
  atom: Atom,
  mask: int,
  data0: clong,
  data1: clong,
  data2: clong,
  data3: clong,
  data4: clong
): bool =
  return true

proc setClientState(client: Client, state: int) =
  discard

proc setFullscreen(client: Client, shouldFullscreen: bool) =
  discard

proc setUrgent(client: Client, shouldBeUrgent: bool) =
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

proc unmanage(client: Client, destroyed: bool) =
  discard

proc updateSizeHints(client: Client) =
  discard

proc updateSystray() =
  discard

proc updateSystrayIconGeom(client: Client, width, height: int) =
  discard

proc view(ui: cuint) =
  discard

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

