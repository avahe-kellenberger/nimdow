import
  x11 / [x, xlib, xutil, xatom, xft, keysym, xinerama],
  std/decls,
  math,
  strformat,
  options

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
  BUTTONMASK = ButtonPressMask or ButtonReleaseMask
  MOUSEMASK = BUTTONMASK or PointerMotionMask

const
  colorBorder: uint = 0

type
  Click = enum
    ClkTagBar, ClkLtSymbol, ClkStatusText, ClkWinTitle,
    ClkClientWin, ClkRootWin, ClkLast
  ColorScheme = enum
    SchemeNorm, SchemeSel

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
    oldState: bool
    name: string

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

  Key = object
    modifier: int
    keysym: KeySym
    callback: proc()

  Systray = object
    window: Window
    icons: Client

# Function declarations
proc applyRules(client: var Client)
proc applySizeHints(
  client: Client,
  x,
  y,
  width,
  height: var int,
  interact: bool
): bool
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
proc configureNotify(e: PXEvent)
proc configureRequest(e: PXEvent)
proc createMonitor(): Monitor
proc destroyNotify(e: PXEvent)
proc detach(client: Client)
proc directionToMonitor(dir: int): Monitor
proc drawBar(monitor: Monitor)
proc drawBars()
proc enterNotify(e: PXEvent)
proc expose(e: PXEvent)
proc focus(client: var Client)
proc focusIn(e: PXEvent)
proc focusMonitor(direction: int)
proc focusStack(forward: bool)
proc getProperty*[T](
  window: Window,
  property: Atom,
): Option[T]
proc getRootPointer(x, y: ptr int): bool
proc getState(window: Window): Option[Atom]
proc getSystrayWidth(): uint
proc getTextProperty*(
  window: Window,
  property: Atom,
): Option[string]
proc grabButtons(client: Client, focused: bool)
proc grabKeys()
proc handleEvent(e: PXEvent)
proc incrementNumMasterWindows(delta: int)
proc intersect(monitor: Monitor, x, y, width, height: int): int
proc isUniqueGeom(unique: openArray[XineramaScreenInfo], info: XineramaScreenInfo): bool
proc isVisible(client: Client): bool
proc keyPress(e: PXEvent)
proc killClient()
proc manage(window: Window, winAttr: PXWindowAttributes)
proc mappingNotify(e: PXEvent)
proc mapRequest(e: PXEvent)
proc monocle(monitor: Monitor)
proc motionNotify(e: PXEvent)
proc moveMouse()
proc nextTiled(client: Client): Client
proc pop(client: var Client)
proc propertyNotify(e: PXEvent)
proc quit
proc rectToMonitor(x, y, width, height: int): Monitor
proc removeSystrayIcon(client: Client)
proc resize(client: Client, x, y, width, height: var int, interact: bool)
proc resizeBar(monitor: Monitor)
proc resizeClient(
  client: Client,
  x: int,
  y: int,
  width: int,
  height: int
)
proc resizeRequest(e: PXEvent)
proc resizeMouse
proc restack(monitor: Monitor)
proc run
proc sendEvent(
  window: Window,
  protocol: Atom,
  mask: int,
  data0: clong,
  data1: clong,
  data2: clong,
  data3: clong,
  data4: clong
): bool
proc sendMonitor(client: var Client, monitor: Monitor)
proc setClientState(client: Client, state: int)
proc setFocus(client: Client)
proc setFullscreen(client: Client, shouldFullscreen: bool)
proc setGaps(
  outerHorizontal,
  outerVertical,
  innerHorizontal,
  innerVertical: uint
)

proc setUrgent(client: Client, shouldBeUrgent: bool)
proc showhide(client: Client)
proc systrayToMonitor(monitor: Monitor): Monitor
proc textWidth(str: string): uint
proc toggleFloating()
proc unfocus(client: Client, setFocus: bool)
proc unmanage(client: Client, destroyed: bool)
proc updateBars()
proc updateGeom(): bool
proc updateNumlockMask()
proc updateSizeHints(client: Client)
proc updateStatus()
proc updateSystray()
proc updateSystrayIconGeom(client: Client, width, height: int)
proc updateSystrayIconState(client: Client, event: XPropertyEvent)
proc updateTitle(client: Client)
proc updateWindowType(client: Client)
proc updateWMHints(client: Client)
proc view(ui: cuint)
proc warp(client: Client)
proc windowToClient(window: Window): Client
proc windowToMonitor(window: Window): Monitor
proc windowToSystrayIcon(window: Window): Client
proc xError(display: PDisplay, event: PXErrorEvent): cint {.cdecl}
proc xErrorDummy(display: PDisplay, event: PXErrorEvent): cint {.cdecl}
proc xErrorStart(display: PDisplay, e: PXErrorEvent): cint {.cdecl}

var
  display: PDisplay
  statusText: string
  screen: int
  screenWidth, screenHeight: int
  # TODO: barLeftWidth? LayoutWidth (symbol)?
  barHeight, barLW: int = 0
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
  scheme: seq[PXftColor]
  cursor: Cursor

# config.h vars
var
  respectResizeHints: bool = false
  showSystray: bool = true
  mFactor = 0.5
  numMasterWindows = 1
  showBar = true
  topBar = true
  gapInnerHorizontal = 24
  gapInnerVertical = 24
  gapOuterHorizontal = 24
  gapOuterVertical = 24
  smartGaps = true
  systraySpacing = 2
  snap = 0

  # Button defs
  buttons: array[1, Button] =
    [
      Button(click: ClkClientWin, eventMask: MODKEY, button: Button1, callback: movemouse)
    ]

  # TODO: Populate the keys
  keys: array[1, Key] =
    [
      Key(modifier: MODKEY, keysym: XK_j, callback: proc() = focusStack(true))
    ]

# TODO: Need to invoke xatoms.initAtoms

template cleanMask(mask: uint): uint =
  (mask and not(numlockMask or LockMask)) and
  (ShiftMask or ControlMask or Mod1Mask or Mod2Mask or Mod3Mask or Mod4Mask or Mod5Mask)

template NIL[T](): var T =
  var dummyT: T
  dummyT

template totalWidth(client: Client): int =
  client.width + client.borderWidth.int * 2

template totalHeight(client: Client): int =
  client.height + client.borderWidth.int * 2

template `$`(scheme: ColorScheme): int =
  ord(scheme)

template doWhile(a: typed, b: untyped): untyped =
  while true:
    b
    if not a:
      break

proc applyRules(client: var Client) =
  # We don't care about dwm rules currently
  discard

proc applySizeHints(
  client: Client,
  x,
  y,
  width,
  height: var int,
  interact: bool
): bool =
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
  var event: PXConfigureEvent
  event.theType = ConfigureNotify
  event.display = display
  event.event = client.window
  event.window = client.window
  event.x = client.x
  event.y = client.y
  event.width = client.width
  event.height = client.height
  event.border_width = client.borderWidth.cint
  event.above = None;
  event.override_redirect = false;

  discard XSendEvent(
    display,
    client.window,
    false,
    StructureNotifyMask,
    cast[PXEvent](event)
  )

proc configureNotify(e: PXEvent) =
  var
    monitor: Monitor
    client: Client
    event: PXConfigureEvent = e.xconfigure.addr
    dirty: bool

  # TODO: updategeom handling sucks, needs to be simplified
  if event.window != root:
    return

  dirty = screenWidth != event.width or screenHeight != event.height
  screenWidth = event.width
  screenHeight = event.height
  if updateGeom() or dirty:
    draw.resize(screenWidth, barHeight)
    updateBars()
    monitor = monitors
    while monitor != nil:
      client = monitor.clients
      while client != nil:
        if client.isFullscreen:
          resizeClient(
            client,
            monitor.screenX,
            monitor.screenY,
            monitor.screenWidth,
            monitor.screenHeight
          )
        client = client.next
      monitor = monitor.next

    focus(NIL[Client])
    arrange(NIL[Monitor])

proc configureRequest(e: PXEvent) =
  var
    client: Client
    monitor: Monitor
    event: PXConfigureRequestEvent = e.xconfigurerequest.addr
    winChanges: XWindowChanges

  client = windowToClient(event.window)
  if client != nil:
    if (event.value_mask or CWBorderWidth) != 0:
      client.borderWidth = event.border_width
    elif client.isFloating:
      monitor = client.monitor

      if (event.value_mask and CWX) != 0:
        client.oldX = client.x
        client.x = monitor.screenX + event.x
      if (event.value_mask and CWY) != 0:
        client.oldY = client.y
        client.y = monitor.screenY + event.y
      if (event.value_mask and CWWidth) != 0:
        client.oldWidth = client.width
        client.width = event.width
      if (event.value_mask and CWHeight) != 0:
        client.oldHeight = client.height
        client.height = event.height

      if (client.x + client.width) > monitor.screenX + monitor.screenWidth:
        # Center in the x direction
        client.x = monitor.screenX + (monitor.screenWidth div 2 - totalWidth(client) div 2)
        # Center in the y direction
        client.y = monitor.screenY + (monitor.screenHeight div 2 - totalHeight(client) div 2)

        if (event.value_mask and (CWX or CWY)) != 0 and not
           (event.value_mask and (CWWidth or CWHeight)) != 0:
          configure(client)

        if isVisible(client):
          discard XMoveResizeWindow(
            display,
            client.window,
            client.x,
            client.y,
            client.width,
            client.height
          )
        else:
          client.needsResize = true
      else:
        configure(client)
    else:
      winChanges.x = event.x
      winChanges.y = event.y
      winChanges.width = event.width
      winChanges.height = event.height
      winChanges.border_width = event.border_width
      winChanges.sibling = event.above
      winChanges.stack_mode = event.detail
      discard XConfigureWindow(
        display,
        event.window,
        event.value_mask.cuint,
        winChanges.addr
      )
  discard XSync(display, false)

proc createMonitor(): Monitor =
  result.tagset[0] = 1
  result.tagset[1] = 1
  result.mFactor = mFactor
  result.numMasterWindows = numMasterWindows
  result.showBar = showBar
  result.topBar = topBar
  result.gapInnerHorizontal = gapInnerHorizontal
  result.gapInnerVertical = gapInnerVertical
  result.gapOuterHorizontal = gapOuterHorizontal
  result.gapOuterVertical = gapOuterVertical

  result.pertag.currentTag = 1
  result.pertag.previousTag = 1

  for i in 0..TAGS.high:
    result.pertag.numMasterWindows[i] = result.numMasterWindows
    result.pertag.mFactors[i] = result.mFactor
    result.pertag.selectedLayouts[i] = result.selectedLayout
    result.pertag.showBars[i] = result.showBar

proc destroyNotify(e: PXEvent) =
  var
    event: PXDestroyWindowEvent = e.xdestroywindow
    client: Client = windowToClient(event.window)

  if client != nil:
    unmanage(client, true)
  else:
    client = windowToSystrayIcon(event.window)
    if client != nil:
      removeSystrayIcon(client)
      resizeBar(selectedMonitor)
      updateSystray()

proc detach(client: Client) =
  var tempClient {.byaddr.} = client.monitor.clients
  while tempClient != nil and tempClient != client:
    tempClient = tempClient.next
  tempClient = client.next

proc detachStack(client: Client) =
  var clientRef {.byaddr.} = client.monitor.clientStack
  while clientRef != nil and clientRef != client:
    clientRef = clientRef.next
  clientRef = client.stackNext

  if client == client.monitor.selectedClient:
    var tempClient = client.monitor.clientStack
    while tempClient != nil and not isVisible(tempClient):
      tempClient = tempClient.stackNext
    client.monitor.selectedClient = tempClient

proc directionToMonitor(dir: int): Monitor =
  if dir > 0:
    result = selectedMonitor.next
    if result == nil:
      result = monitors
  elif selectedMonitor == monitors:
    result = monitors
    while result.next != nil:
      result = result.next
  else:
    result = monitors
    while result.next != selectedMonitor:
      result = result.next

proc drawBar(monitor: Monitor) =
  var
    systrayWidth: uint
    statusWidth: uint
    occupied: uint
    urgent: uint

  if showSystray and monitor == systrayToMonitor(monitor):
    systrayWidth = getSystrayWidth()

  # Draw status first so it can be overdrawn by tags later
  draw.setScheme(scheme[$SchemeNorm])
  statusWidth = textWidth(statusText) - lrpad div 2 + 2 # 2px right padding
  discard draw.text(
    monitor.windowAreaWidth - screenWidth - systrayWidth.int,
    0,
    screenWidth,
    barHeight,
    lrpad div 2 - 2,
    statusText,
    false
  )
  resizeBar(monitor)

  var client = monitor.clients
  while client != nil:
    occupied = occupied or client.tags
    if client.isUrgent:
      urgent = urgent or client.tags
    client = client.next

  var
    x, width: int
    boxs = draw.fonts.height div 9
    boxWidth = draw.fonts.height div 6 + 2

  for i in 0..TAGS.high:
    width = textWidth(TAGS[i]).int

    let
      isUrgent = (urgent and 1).shl(i) != 0
      isOccupied = (occupied and 1).shl(i) != 0
      tagMask = (monitor.tagset[monitor.selectedTags] and 1).shl(i)
      schemeIndex = if tagMask != 0: $SchemeSel else: $SchemeNorm

    draw.setScheme(scheme[schemeIndex])

    discard draw.text(x, 0, width, barHeight, lrpad div 2, TAGS[i], isUrgent)

    if isOccupied:
      let
        filled = monitor == selectedMonitor and
                 selectedMonitor.selectedClient != nil and
                 (selectedMonitor.selectedClient.tags and 1).shl(i) != 0

      draw.rect(x + boxs.int, boxs.int, boxWidth, boxWidth, filled, isUrgent)

    x.inc(width)

  width = 0
  barLW = 0
  draw.setScheme(scheme[$SchemeNorm])
  x = draw.text(x, 0, width, barHeight, lrpad div 2, "", false).int

  width = monitor.windowAreaWidth - screenWidth - systrayWidth.int - x

  if width > barHeight:
    if monitor.selectedClient != nil:
      let schemeIndex = if monitor == selectedMonitor: $SchemeSel else: $SchemeNorm
      draw.setScheme(scheme[schemeIndex])

      let middle = (monitor.windowAreaWidth - textWidth(monitor.selectedClient.name)) div 2 - x + lrpad div 2
      discard draw.text(x, 0, width, barHeight, middle, monitor.selectedClient.name, false)

      if monitor.selectedClient.isFloating:
        draw.rect(x + boxs.int, boxs.int, boxWidth, boxWidth, monitor.selectedClient.isFixed, false)
    else:
      draw.setScheme(scheme[$SchemeNorm])
      draw.rect(x, 0, width, barHeight, true, true)

  draw.map(monitor.bar, 0, 0, monitor.windowAreaWidth - systrayWidth, barHeight)

proc drawBars() =
  var monitor = monitors
  while monitor != nil:
    drawBar(monitor)
    monitor = monitor.next

proc enterNotify(e: PXEvent) =
  let event = e.xcrossing

  if (event.mode != NotifyNormal or event.detail == NotifyInferior) and
     event.window != root:
    return

  var client = windowToClient(event.window)
  let monitor = if client != nil: client.monitor else: windowToMonitor(event.window)

  if monitor != selectedMonitor:
    unfocus(selectedMonitor.selectedClient, true)
    selectedMonitor = monitor
  elif client == nil or client == selectedMonitor.selectedClient:
    return

  focus(client)

proc expose(e: PXEvent) =
  let
    event = e.xexpose
    monitor = windowToMonitor(event.window)

  if event.count == 0 and monitor != nil:
    drawBar(monitor)
    if monitor == selectedMonitor:
      updateSystray()

proc focus(client: var Client) =
  if client == nil or not client.isVisible():
    client = selectedMonitor.clientStack
    while client != nil and not client.isVisible():
      client = client.stackNext

proc focusIn(e: PXEvent) =
  # There are some broken focus acquiring clients needing extra handling
  let event = e.xfocus

  if selectedMonitor.selectedClient != nil and
     event.window != selectedMonitor.selectedClient.window:
    setFocus(selectedMonitor.selectedClient)

proc focusMonitor(direction: int) =
  if monitors.next == nil:
    return
  let monitor = directionToMonitor(direction)
  if monitor == selectedMonitor:
    return

  unfocus(selectedMonitor.selectedClient, false)
  selectedMonitor = monitor
  focus(NIL[Client])
  warp(selectedMonitor.selectedClient)

proc focusStack(forward: bool) =
  # TODO: 1 forward, -1 backward (in C)
  var client: Client
  if selectedMonitor.selectedClient == nil:
    return
  if forward:
    client = selectedMonitor.selectedClient.next
    while client != nil and not isVisible(client):
      client = client.next
    if client == nil:
      client = selectedMonitor.clients
      while client != nil and not isVisible(client):
        client = client.next
  else:
    var tempClient: Client = selectedMonitor.clients
    while tempClient != selectedMonitor.selectedClient:
      if isVisible(tempClient):
        client = tempClient
      if client == nil:
        while tempClient != nil:
          if isVisible(tempClient):
            client = tempClient
          tempClient = tempClient.next
      tempClient = tempClient.next

  if client != nil:
    focus(client)
    restack(selectedMonitor)

proc getProperty*[T](
  window: Window,
  property: Atom,
): Option[T] =
  # NOTE: This is my own code, not translated from dwm
  var
    actualTypeReturn: Atom
    actualFormatReturn: cint
    numItemsReturn: culong
    bytesAfterReturn: culong
    propReturn: ptr T

  discard XGetWindowProperty(
    display,
    window,
    property,
    0,
    0.clong.high,
    false,
    AnyPropertyType,
    actualTypeReturn.addr,
    actualFormatReturn.addr,
    numItemsReturn.addr,
    bytesAfterReturn.addr,
    cast[PPcuchar](propReturn.addr)
  )
  if numItemsReturn > 0.culong:
    return propReturn[].option
  else:
    return none(T)

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

proc getState(window: Window): Option[Atom] =
  return getProperty[Atom](window, $WMState)

proc getSystrayWidth(): uint =
  var width: uint

  if showSystray:
    var i = systray.icons
    while i != nil:
      width += i.width + systraySpacing
      i = i.next
    width += systraySpacing

  return max(1.uint, width)

proc getTextProperty*(
  window: Window,
  property: Atom,
): Option[string] =
  var
    actualTypeReturn: Atom
    actualFormatReturn: cint
    numItemsReturn: culong
    bytesAfterReturn: culong
    str: string = newString(300)
    propReturn = cast[ptr cstring](addr str)

  discard XGetWindowProperty(
    display,
    window,
    property,
    0,
    0.clong.high,
    false,
    AnyPropertyType,
    actualTypeReturn.addr,
    actualFormatReturn.addr,
    numItemsReturn.addr,
    bytesAfterReturn.addr,
    cast[PPcuchar](propReturn)
  )

  if numItemsReturn > 0.culong:
    let val = $propReturn[]
    return val.option
  else:
    return none(string)

proc grabButtons(client: Client, focused: bool) =
  updateNumlockMask()

  discard XUngrabButton(display, AnyButton, AnyModifier, client.window)

  if not focused:
    discard XGrabButton(
      display,
      AnyButton,
      AnyModifier,
      client.window,
      false,
      BUTTONMASK,
      GrabModeSync,
      GrabModeSync,
      None,
      None
    )

  const modifiers = [uint 0, LockMask, numlockMask, numlockMask or LockMask]

  for button in buttons:
    if button.click == ClkClientWin:
      for modifier in modifiers:
        discard XGrabButton(
          display,
          button.button.cint,
          (button.eventMask or modifier).cint,
          client.window,
          false,
          BUTTONMASK,
          GrabModeAsync,
          GrabModeSync,
          None,
          None
        )

proc grabKeys() =
  updateNumlockMask()
  const modifiers = [uint 0, LockMask, numlockMask, numlockMask or LockMask]
  discard XUngrabKey(display, AnyKey, AnyModifier, root)

  var keycode: KeyCode
  for key in keys:
    keycode = XKeySymToKeycode(display, key.key)
    if keycode == 0:
      continue
    for modifier in modifiers:
      discard XGrabKey(
        display,
        keycode.cint,
        (key.modifier or modifier).cint,
        root,
        true,
        GrabModeAsync,
        GrabModeAsync
      )
proc handleEvent(e: PXEvent) =
  discard

proc incrementNumMasterWindows(delta: int) =
  let numMasterWindows = max(0, selectedMonitor.numMasterWindows + delta)
  selectedMonitor.numMasterWindows = numMasterWindows
  selectedMonitor.pertag.numMasterWindows[selectedMonitor.pertag.currentTag] = numMasterWindows

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

proc isUniqueGeom(unique: openArray[XineramaScreenInfo], info: XineramaScreenInfo): bool =
  # TODO: Not sure this is correctly translated
  # Why does the C code iterate over this in reverse?
  for i in unique.len..0:
    let uniqueInfo = unique[i]
    if uniqueInfo.x_org == info.x_org and
       uniqueInfo.y_org == info.y_org and
       uniqueInfo.width == info.width and
       uniqueInfo.height == info.height:
      return false
  return true

proc isVisible(client: Client): bool =
  let mask = client.tags and client.monitor.tagset[client.monitor.selectedTags]
  return mask != 0

proc keyPress(e: PXEvent) =
  let
    event = e.xkey
    keysym = XKeycodeToKeysym(display, event.keycode.KeyCode, 0)

  for key in keys:
    if keysym == key.keysym and
       cleanMask(key.modifier) == cleanMask(event.state):
      key.callback()

proc killClient() =
  if selectedMonitor.selectedClient == nil:
    return

  let eventWasSent = sendEvent(
    selectedMonitor.selectedClient.window,
    $WMDelete,
    NoEventMask,
    ($WMDelete).clong,
    CurrentTime,
    0,
    0,
    0
  )

  if not eventWasSent:
    discard XGrabServer(display)
    discard XSetErrorHandler(xErrorDummy)
    discard XSetCloseDownMode(display, DestroyAll)
    discard XKillClient(display, selectedMonitor.selectedClient.window)
    discard XSync(display, false)
    discard XSetErrorHandler(xerror)
    discard XUngrabServer(display)

# TODO: Skipping xrdb for now

proc manage(window: Window, winAttr: PXWindowAttributes) =
  var
    client, transientClient: Client
    transientWindow: Window = None

  client.window = window
  client.x = winAttr.x
  client.oldX = winAttr.x
  client.y = winAttr.y
  client.oldY = winAttr.y
  client.width = winAttr.width
  client.oldWidth = winAttr.width
  client.height = winAttr.height
  client.oldHeight = winAttr.height
  client.oldBorderWidth = winAttr.border_width

  updateTitle(client)
  let isTransient = XGetTransientForHint(display, window, transientWindow.addr) != 0
  transientClient = windowToClient(transientWindow)
  if isTransient and transientClient != nil:
    client.monitor = transientClient.monitor
    client.tags = transientClient.tags
  else:
    client.monitor = selectedMonitor
    applyRules(client)

  if client.x + totalWidth(client) > client.monitor.screenX + client.monitor.screenWidth:
    client.x = client.monitor.screenX + client.monitor.screenWidth - totalWidth(client)
  if client.y + totalHeight(client) > client.monitor.screenY + client.monitor.screenHeight:
    client.y = client.monitor.screenY + client.monitor.screenHeight - totalHeight(client)
  client.x = max(client.x, client.monitor.screenX)

  # Only fix client y-offset, if the client center might cover the bar
  if client.monitor.barY == client.monitor.screenY and
     client.x + (client.width div 2) >= client.monitor.windowAreaX and
     client.x + client.width div 2 < client.monitor.windowAreaX + client.monitor.windowAreaWidth:
    client.y = max(client.y, barHeight)
  else:
    client.y = max(client.y, client.monitor.screenY)

  if client.isCentered:
    client.x = (client.monitor.screenWidth - totalWidth(client)) div 2
    client.y = (client.monitor.screenHeight - totalHeight(client)) div 2

  var winChanges: XWindowChanges
  winChanges.border_width = client.borderWidth.cint
  discard XConfigureWindow(display, window, CWBorderWidth, winChanges.addr)
  # TODO: scheme[SchemeNorm][ColBorder].pixel how to handle this?
  discard XSetWindowBorder(display, window, scheme[$SchemeNorm].pixel)
  # Propagates border_width, if size doesn't change
  configure(client)

  updateWindowType(client)
  updateSizeHints(client)
  updateWMHints(client)

  discard XSelectInput(
    display,
    window,
    EnterWindowMask or FocusChangeMask or PropertyChangeMask or StructureNotifyMask
  )
  grabButtons(client, false)

  if not client.isFloating:
    client.isFloating = transientWindow != None or client.isFixed
    client.oldState = client.isFloating

  if client.isFloating:
    discard XRaiseWindow(display, window)

  attachBelow(client)
  attachStack(client)
  discard XChangeProperty(
    display,
    root,
    $NetClientList,
    XA_WINDOW,
    32,
    PropModeAppend,
    cast[Pcuchar](client.window.addr),
    1
  )
  discard XMoveResizeWindow(
    display,
    client.window,
    client.x + 2 * screenWidth,
    client.y,
    client.width,
    client.height
  )
  setClientState(client, NormalState)

  if client.monitor == selectedMonitor:
    unfocus(selectedMonitor.selectedClient, false)

  client.monitor.selectedClient = client
  arrange(client.monitor)
  discard XMapWindow(display, client.window)
  focus(NIL[Client])

proc mappingNotify(e: PXEvent) =
  let event: PXMappingEvent = e.xmapping.addr
  discard XRefreshKeyboardMapping(event)
  if event.request == MappingKeyboard:
    grabKeys()

proc mapRequest(e: PXEvent) =
  let event = e.xmaprequest

  let client = windowToSystrayIcon(event.window)
  if client != nil:
    discard sendEvent(
      client.window,
      $Xembed,
      StructureNotifyMask,
      CurrentTime,
      XEMBED_WINDOW_ACTIVATE,
      0,
      systray.window.clong,
      XEMBED_EMBEDDED_VERSION
    )

  var winAttr: XWindowAttributes
  if XGetWindowAttributes(display, event.window, winAttr.addr) == 0 or
     winAttr.override_redirect:
    return

  if windowToClient(event.window) == nil:
    manage(event.window, winAttr.addr)

proc monocle(monitor: Monitor) =
  var
    client: Client = monitor.clients

  while client != nil:
    client = nextTiled(monitor.clients)
    while client != nil:
      client = nextTiled(client.next)
    var
      x = monitor.windowAreaX
      y = monitor.windowAreaY
      width = monitor.windowAreaWidth - 2 * client.borderWidth.int
      height = monitor.windowAreaHeight - 2 * client.borderWidth.int
    resize(client, x, y, width, height, false)
    client = client.next

# Static var in dwm for motionNotify
var previousMonitor: Monitor
proc motionNotify(e: PXEvent) =
  let event = e.xmotion

  if event.window != root:
    return

  var
    monitor = rectToMonitor(event.x_root, event.y_root, 1, 1)
  if monitor != previousMonitor and previousMonitor != nil:
    unfocus(selectedMonitor.selectedClient, true)
    selectedMonitor = monitor
    focus(NIL[Client])
  previousMonitor = monitor

proc moveMouse() =
  var
    client = selectedMonitor.selectedClient

  if client == nil or client.isFullscreen:
    return

  var
    oldClientX, oldClientY, x, y: int

  restack(selectedMonitor)
  oldClientX = client.x
  oldClientY = client.y

  if XGrabPointer(
    display,
    root,
    false,
    MOUSEMASK,
    GrabModeAsync,
    GrabModeAsync,
    None,
    cursor,
    CurrentTime
  ) != GrabSuccess:
    return

  if not getRootPointer(x.addr, y.addr):
    return

  var
    event: XEvent
    lastTime: Time
    newX, newY: int

  doWhile(event.theType != ButtonRelease):
    discard XMaskEvent(
      display,
      MOUSEMASK or ExposureMask or SubstructureRedirectMask,
      event.addr
    )

    case event.theType:
      of ConfigureRequest,
         Expose,
         MapRequest:
        handleEvent(event.addr)
      of MotionNotify:
        if (event.xmotion.time - lastTime).float <= MIN_UPDATE_INTERVAL:
          continue
        lastTime = event.xmotion.time
        newX = oldClientX + (event.xmotion.x - x)
        newY = oldClientY + (event.xmotion.y - y)

        if abs(selectedMonitor.windowAreaX - newX) < snap:
          newX = selectedMonitor.windowAreaX
        elif abs((selectedMonitor.windowAreaX + selectedMonitor.windowAreaWidth) - (newX + totalWidth(client))) < snap:
          newX = selectedMonitor.windowAreaX + selectedMonitor.windowAreaWidth - totalWidth(client)

        if abs(selectedMonitor.windowAreaY - newY) < snap:
          newY = selectedMonitor.windowAreaY
        elif abs((selectedMonitor.windowAreaY + selectedMonitor.windowAreaHeight) - (newY + totalHeight(client))) < snap:
          newY = selectedMonitor.windowAreaY + selectedMonitor.windowAreaHeight - totalHeight(client)

        if not client.isFloating and (abs(newX - client.x) > snap or abs(newY - client.y) > snap):
          toggleFloating()

        if client.isFloating:
          resize(client, newX, newY, client.width, client.height, true)
      else:
        discard

    discard XUngrabPointer(display, CurrentTime)

    let monitor = rectToMonitor(client.x, client.y, client.width, client.height)
    if monitor != selectedMonitor:
      sendMonitor(client, monitor)
      selectedMonitor = monitor
      focus(NIL[Client])

proc nextTiled(client: Client): Client =
  result = client
  while result != nil and (result.isFloating or not isVisible(result)):
    result = client.next

proc pop(client: var Client) =
  detach(client)
  attach(client)
  focus(client)
  arrange(client.monitor)

proc propertyNotify(e: PXEvent) =
  let event = e.xproperty
  var client = windowToSystrayIcon(event.window)

  if client != nil:
    if event.atom == XA_WM_NORMAL_HINTS:
      updateSizeHints(client)
      updateSystrayIconGeom(client, client.width, client.height)
    else:
      updateSystrayIconState(client, event)

    resizeBar(selectedMonitor)
    updateSystray()

  if event.window == root and event.atom == XA_WM_NAME:
    updateStatus()
  elif event.state == PropertyDelete:
    return
  else:
    client = windowToClient(event.window)
    if client == nil:
      return

    case event.atom:
      of XA_WM_TRANSIENT_FOR:
        var trans: Window
        if not client.isFloating and XGetTransientForHint(display, client.window, trans.addr) != 0:
          client.isFloating = (windowToClient(trans) != nil)
          if client.isFloating:
            arrange(client.monitor)

      of XA_WM_NORMAL_HINTS:
        updateSizeHints(client)

      of XA_WM_HINTS:
        updateWMHints(client)
        drawBars()
      else:
        discard

    if event.atom == XA_WM_NAME or event.atom == $NetWMName:
      updateTitle(client)
      if client == client.monitor.selectedClient:
        drawBar(client.monitor)

    if event.atom == $NetWMWindowType:
      updateWindowType(client)

proc quit =
  running = false

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

proc removeSystrayIcon(client: Client) =
  discard

proc resize(client: Client, x, y, width, height: var int, interact: bool) =
  if applySizeHints(client, x, y, width, height, interact):
    resizeClient(client, x, y, width, height)

proc resizeBar(monitor: Monitor) =
  discard

proc resizeClient(
  client: Client,
  x: int,
  y: int,
  width: int,
  height: int
) =
  discard

proc resizeRequest(e: PXEvent) =
  let
    event = e.xresizerequest
    client = windowToSystrayIcon(event.window)

  if client != nil:
    updateSystrayIconGeom(client, event.width, event.height)
    resizeBar(selectedMonitor)
    updateSystray()

proc resizeMouse =
  let client = selectedMonitor.selectedClient
  if client == nil or client.isFullscreen:
    return

  restack(selectedMonitor)
  if XGrabPointer(
    display,
    root,
    false,
    MOUSEMASK,
    GrabModeAsync,
    GrabModeAsync,
    None,
    cursor,
    CurrentTime
  ) != GrabSuccess:
    return

  discard XWarpPointer(
    display,
    None,
    client.window,
    0,
    0,
    0,
    0,
    client.width + client.borderWidth.int - 1,
    client.height + client.borderWidth.int - 1
  )

  let
    oldClientX = client.x
    oldClientY = client.y
  var
    event: XEvent
    lastTime: Time
    newWidth, newHeight: int

  doWhile(event.theType != ButtonRelease):
    discard XMaskEvent(display, MOUSEMASK or ExposureMask or SubstructureRedirectMask, event.addr)
    case event.theType:

      of ConfigureRequest, Expose, MapRequest:
        handleEvent(event.addr)

      of MotionNotify:
        if (event.xmotion.time - lastTime) <= MIN_UPDATE_INTERVAL:
          continue
        lastTime = event.xmotion.time

        newWidth = max(event.xmotion.x - oldClientX - 2 * client.borderWidth.int + 1, 1)
        newHeight = max(event.xmotion.y - oldClientY - 2 * client.borderWidth.int + 1, 1)

        if client.monitor.windowAreaX + newWidth >= selectedMonitor.windowAreaX and
           client.monitor.windowAreaX + newWidth <= selectedMonitor.windowAreaX + selectedMonitor.windowAreaWidth and
           client.monitor.windowAreaY + newHeight >= selectedMonitor.windowAreaY and
           client.monitor.windowAreaY + newHeight <= selectedMonitor.windowAreaY + selectedMonitor.windowAreaHeight:
          if not client.isFloating and
             abs(newWidth - client.width) > snap or
             abs(newHeight - client.height) > snap:
               toggleFloating()

        if client.isFloating:
          resize(client, client.x, client.y, newWidth, newHeight, true)

      else:
        discard

  discard XWarpPointer(
    display,
    None,
    client.window,
    0,
    0,
    0,
    0,
    client.width + client.borderWidth.int - 1,
    client.height + client.borderWidth.int - 1
  )
  discard XUngrabPointer(display, CurrentTime)

  while XCheckMaskEvent(display, EnterWindowMask, event.addr):
    discard

  let monitor = rectToMonitor(client.x, client.y, client.width, client.height)
  if monitor != selectedMonitor:
    sendMonitor(client, monitor)
    selectedMonitor = monitor
    focus(NIL[Client])

proc restack(monitor: Monitor) =
  drawBar(monitor)

  if monitor.selectedClient == nil:
    return

  if monitor.selectedClient.isFloating:
    discard XRaiseWindow(display, monitor.selectedClient.window)

  var winChanges: XWindowChanges
  winChanges.stack_mode = Below
  winChanges.sibling = monitor.bar

  var client = monitor.clientStack
  while client != nil:
    if not client.isFloating and isVisible(client):
      discard XConfigureWindow(
        display,
        client.window,
        CWSibling or CWStackMode,
        winChanges.addr
      )
    client = client.next

  discard XSync(display, false)

  var event: XEvent
  while XCheckMaskEvent(display, EnterWindowMask, event.addr):
    discard

  if monitor == selectedMonitor and
     (monitor.tagset[monitor.selectedTags] and monitor.selectedClient.tags) != 0:
    warp(monitor.selectedClient)

proc run =
  discard XSync(display, false)

  # Main event loop
  var event: XEvent
  while running and XNextEvent(display, event.addr) != 0:
    handleEvent(event.addr)

proc scan =
  var
    num: uint
    d1, d2: Window
    windows: PWindow

  if XQueryTree(display, root, d1.addr, d2.addr, windows.addr, cast[Pcuint](num.addr)) == 0:
    return

  var winAttr: XWindowAttributes
  let wins = cast[ptr UncheckedArray[Window]](windows)
  for i in 0..<num:
    if XGetWindowAttributes(display, wins[i], winAttr.addr) == 0 or
       winAttr.override_redirect or
       XGetTransientForHint(display, wins[i], d1.addr) != 0:
      continue
    let state = getState(wins[i])
    if winAttr.map_state == IsViewable or
       state.isSome and state.get == IconicState:
      manage(wins[i], winAttr.addr)

  if wins != nil:
    discard XFree(wins)

proc sendEvent(
  window: Window,
  protocol: Atom,
  mask: int,
  data0: clong,
  data1: clong,
  data2: clong,
  data3: clong,
  data4: clong
): bool =
  var
    event: XEvent
    protocols: PAtom
    messageType: Atom
    numProtocols: int

  if protocol == $WMTakeFocus or protocol == $WMDelete:
    messageType = $WMProtocols
    if XGetWMProtocols(display, window, protocols.addr, cast[Pcint](numProtocols.addr)) != 0:
      let protocolsArr = cast[ptr UncheckedArray[Atom]](protocols)
      while not result and numProtocols > 0:
        result = protocolsArr[numProtocols] == protocol
        numProtocols.dec
      discard XFree(protocols)
  else:
    result = true
    messageType = protocol

  if result:
    event.theType = ClientMessage
    event.xclient.window = window
    event.xclient.message_type = messageType
    event.xclient.format = 32
    event.xclient.data.l[0] = data0
    event.xclient.data.l[1] = data1
    event.xclient.data.l[2] = data2
    event.xclient.data.l[3] = data3
    event.xclient.data.l[4] = data4
    discard XSendEvent(display, window, false, mask, event.addr)

proc sendMonitor(client: var Client, monitor: Monitor) =
  if client.monitor == monitor:
    return

  unfocus(client, true)
  detach(client)
  detachStack(client)
  client.monitor = monitor
  # Assign tags of target monitor
  client.tags = monitor.tagset[monitor.selectedTags]
  attachBelow(client)
  attachStack(client)
  focus(NIL[Client])
  arrange(NIL[Monitor])

proc setClientState(client: Client, state: int) =
  var data = [state.clong, None.clong]

  discard XChangeProperty(
    display,
    client.window,
    $WMState,
    $WMState,
    32,
    PropModeReplace,
    cast[Pcuchar](data.addr),
    2
  )

proc setFocus(client: Client) =
  if not client.neverFocus:
    discard XSetInputFocus(display, client.window, RevertToPointerRoot, CurrentTime)
    discard XChangeProperty(
      display,
      root,
      $NetActiveWindow,
      XA_WINDOW,
      32,
      PropModeReplace,
      cast[Pcuchar](client.window.addr),
      1
    )

  discard sendEvent(
    client.window,
    $WMTakeFocus,
    NoEventMask,
    ($WMTakeFocus).clong,
    CurrentTime.clong,
    0.clong,
    0.clong,
    0.clong
  )

proc setFullscreen(client: Client, shouldFullscreen: bool) =
  if shouldFullscreen and not client.isFullscreen:
    discard XChangeProperty(
      display,
      client.window,
      $NetWMState,
      XA_ATOM,
      32,
      PropModeReplace,
      cast[Pcuchar](($NetWMStateFullScreen).addr),
      1
    )
    client.isFullscreen = true
    client.oldState = client.isFloating
    client.oldBorderWidth = client.borderWidth
    client.borderWidth = 0
    client.isFloating = true
    resizeClient(
      client,
      client.monitor.screenX,
      client.monitor.screenY,
      client.monitor.screenWidth,
      client.monitor.screenHeight
    )
    discard XRaiseWindow(display, client.window)

  elif not shouldFullscreen and client.isFullscreen:
    discard XChangeProperty(
      display,
      client.window,
      $NetWMState,
      XA_ATOM,
      32,
      PropModeReplace,
      cast[Pcuchar](0),
      0
    )
    client.isFullscreen = false
    client.isFloating = client.oldState
    client.borderWidth = client.oldBorderWidth
    client.x = client.oldX
    client.y = client.oldY
    client.width = client.oldWidth
    client.height = client.oldHeight
    resizeClient(
      client,
      client.x,
      client.y,
      client.width,
      client.height
    )
    arrange(client.monitor)

proc setGaps(
  outerHorizontal,
  outerVertical,
  innerHorizontal,
  innerVertical: uint
) =
  selectedMonitor.gapOuterHorizontal = outerHorizontal.int
  selectedMonitor.gapOuterVertical = outerVertical.int
  selectedMonitor.gapInnerHorizontal = innerHorizontal.int
  selectedMonitor.gapInnerVertical = innerVertical.int
  arrange(selectedMonitor)

proc setUrgent(client: Client, shouldBeUrgent: bool) =
  client.isUrgent = shouldBeUrgent

  let hints = XGetWMHints(display, client.window)
  if hints == nil:
    return
  hints.flags =
    if shouldBeUrgent:
      hints.flags or XUrgencyHint
    else:
      hints.flags and (not XUrgencyHint)
  discard XSetWMHints(display, client.window, hints)
  discard XFree(hints)

proc showhide(client: Client) =
  if client == nil:
    return

  if isVisible(client):
    # Show clients top down
    discard XMoveWindow(display, client.window, client.x, client.y)
    if client.needsResize:
      client.needsResize = false
      discard XMoveResizeWindow(display, client.window, client.x, client.y, client.width, client.height)
    else:
      discard XMoveWindow(display, client.window, client.x, client.y)

    if client.isFloating and not client.isFullscreen:
      resize(client, client.x, client.y, client.width, client.height, false)

    showhide(client.stackNext)
  else:
    # Hide clients bottom up
    showhide(client.stackNext)
    discard XMoveWindow(display, client.window, totalWidth(client) * -2, client.y)

proc systrayToMonitor(monitor: Monitor): Monitor =
  discard

proc textWidth(str: string): uint =
  draw.fontsetGetWidth(str) + lrpad

proc toggleFloating() =
  discard

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

proc updateBars() =
  discard

proc updateGeom(): bool =
  return true

proc updateNumlockMask() =
  discard

proc updateSizeHints(client: Client) =
  discard

proc updateStatus() =
  discard

proc updateSystray() =
  discard

proc updateSystrayIconGeom(client: Client, width, height: int) =
  discard

proc updateSystrayIconState(client: Client, event: XPropertyEvent) =
  discard

proc updateTitle(client: Client) =
  discard

proc updateWindowType(client: Client) =
  discard

proc updateWMHints(client: Client) =
  discard

proc view(ui: cuint) =
  discard

proc warp(client: Client) =
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

proc windowToSystrayIcon(window: Window): Client =
  discard

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

proc xErrorDummy(display: PDisplay, event: PXErrorEvent): cint {.cdecl} =
  return 0

proc xErrorStart(display: PDisplay, e: PXErrorEvent): cint {.cdecl} =
  quit("nimdow: another window manager is already running", 1)

