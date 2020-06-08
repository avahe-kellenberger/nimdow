import
  x11 / [x, xlib, xutil, xatom],
  math,
  sugar,
  options,
  tables,
  client,
  xatoms,
  monitor,
  tag,
  area,
  config/configloader,
  event/xeventmanager,
  layouts/masterstacklayout

converter intToCint(x: int): cint = x.cint
converter intToCUint(x: int): cuint = x.cuint
converter cintToCUint(x: cint): cuint = x.cuint
converter intToCUchar(x: int): cuchar = x.cuchar
converter clongToCUlong(x: clong): culong = x.culong
converter toXBool(x: bool): XBool = x.XBool
converter toBool(x: XBool): bool = x.bool

const
  wmName = "nimdow"
  tagCount = 9
  minimumUpdateInterval = math.round(1000 / 60).int

type
  MouseState* = enum
    Normal, Moving, Resizing
  WindowManager* = ref object
    display*: PDisplay
    rootWindow*: Window
    eventManager: XEventManager
    config: Config
    monitors: seq[Monitor]
    selectedMonitor: Monitor
    mouseState: MouseState
    lastMousePress: tuple[x, y: int]
    lastMoveResizeClientState: Area
    lastMoveResizeTime: culong
    moveResizingClient: Option[Client]

proc initListeners(this: WindowManager)
proc openDisplay(): PDisplay
proc mapConfigActions*(this: WindowManager)
proc configureRootWindow(this: WindowManager): Window
# XEvents
proc hookConfigKeys*(this: WindowManager)
proc errorHandler(display: PDisplay, error: PXErrorEvent): cint{.cdecl.}
proc onConfigureRequest(this: WindowManager, e: XConfigureRequestEvent)
proc getProperty[T](
  this: WindowManager,
  window: Window,
  property: Atom
): Option[T]
proc onClientMessage(this: WindowManager, e: XClientMessageEvent)
proc onMapRequest(this: WindowManager, e: XMapRequestEvent)
proc onMotionNotify(this: WindowManager, e: XMotionEvent)
proc onEnterNotify(this: WindowManager, e: XCrossingEvent)
proc onFocusIn(this: WindowManager, e: XFocusChangeEvent)
proc handleButtonPressed(this: WindowManager, e: XButtonEvent)
proc handleButtonReleased(this: WindowManager, e: XButtonEvent)
proc handleMouseMotion(this: WindowManager, e: XMotionEvent)
proc resize(this: WindowManager, client: Client, x, y: int, width, height: uint)

proc newWindowManager*(eventManager: XEventManager, config: Config): WindowManager =
  result = WindowManager()
  result.display = openDisplay()
  result.rootWindow = result.configureRootWindow()
  result.eventManager = eventManager
  result.config = config
  # Populate atoms
  xatoms.WMAtoms = xatoms.getWMAtoms(result.display)
  xatoms.NetAtoms = xatoms.getNetAtoms(result.display)
  xatoms.XAtoms = xatoms.getXAtoms(result.display)
  result.initListeners()

  # Create monitors
  for area in result.display.getMonitorAreas(result.rootWindow):
    result.monitors.add(
      newMonitor(result.display, result.rootWindow, area, config)
    )
  result.selectedMonitor = result.monitors[0]

  # Supporting window for NetWMCheck
  let ewmhWindow = XCreateSimpleWindow(result.display, result.rootWindow, 0, 0, 1, 1, 0, 0, 0)

  discard XChangeProperty(result.display,
                          result.rootWindow, 
                          $NetSupportingWMCheck,
                          XA_WINDOW,
                          32,
                          PropModeReplace,
                          cast[Pcuchar](ewmhWindow.unsafeAddr),
                          1)  

  discard XChangeProperty(result.display,
                          ewmhWindow,
                          $NetSupportingWMCheck,
                          XA_WINDOW,
                          32,
                          PropModeReplace,
                          cast[Pcuchar](ewmhWindow.unsafeAddr),
                          1)

  discard XChangeProperty(result.display,
                          ewmhWindow, 
                          $NetWMName,
                          XInternAtom(result.display, "UTF8_STRING", false),
                          8,
                          PropModeReplace,
                          cast[Pcuchar](wmName),
                          wmName.len)

  discard XChangeProperty(result.display,
                          result.rootWindow, 
                          $NetWMName,
                          XInternAtom(result.display, "UTF8_STRING", false),
                          8,
                          PropModeReplace,
                          cast[Pcuchar](wmName),
                          wmName.len)

  discard XChangeProperty(result.display,
                          result.rootWindow, 
                          $NetSupported,
                          XA_ATOM,
                          32,
                          PropModeReplace,
                          cast[Pcuchar](xatoms.NetAtoms.unsafeAddr),
                          ord(NetLast))


  # We need to map this window to be able to set the input focus to it if no other window is available to be focused.
  discard XMapWindow(result.display, ewmhWindow)
  var changes: XWindowChanges
  changes.stack_mode = Below
  discard XConfigureWindow(result.display, ewmhWindow, CWStackMode, addr(changes))

  block setNumberOfDesktops:
    let data: array[1, clong] = [9]
    discard XChangeProperty(result.display,
                            result.rootWindow,
                            $NetNumberOfDesktops,
                            XA_CARDINAL,
                            32,
                            PropModeReplace,
                            cast[Pcuchar](data.unsafeAddr),
                            1)

  block setDesktopNames:
    var tags: array[tagCount, cstring] =
      ["1".cstring,
       "2".cstring,
       "3".cstring,
       "4".cstring,
       "5".cstring,
       "6".cstring,
       "7".cstring,
       "8".cstring,
       "9".cstring]
    var text: XTextProperty
    discard Xutf8TextListToTextProperty(result.display,
                                        cast[PPChar](tags[0].addr),
                                        tagCount,
                                        XUTF8StringStyle,
                                        text.unsafeAddr)
    XSetTextProperty(result.display,
                     result.rootWindow,
                     text.unsafeAddr,
                     $NetDesktopNames)

  block setDesktopViewport:
    let data: array[2, clong] = [0, 0]
    discard XChangeProperty(result.display,
                            result.rootWindow,
                            $NetDesktopViewport,
                            XA_CARDINAL,
                            32,
                            PropModeReplace,
                            cast[Pcuchar](data.unsafeAddr),
                            2)

proc initListeners(this: WindowManager) =
  discard XSetErrorHandler(errorHandler)
  this.eventManager.addListener((e: XEvent) => onConfigureRequest(this, e.xconfigurerequest), ConfigureRequest)
  this.eventManager.addListener((e: XEvent) => onClientMessage(this, e.xclient), ClientMessage)
  this.eventManager.addListener((e: XEvent) => onMapRequest(this, e.xmaprequest), MapRequest)
  this.eventManager.addListener((e: XEvent) => onMotionNotify(this, e.xmotion), MotionNotify)
  this.eventManager.addListener((e: XEvent) => onEnterNotify(this, e.xcrossing), EnterNotify)
  this.eventManager.addListener((e: XEvent) => onFocusIn(this, e.xfocus), FocusIn)
  this.eventManager.addListener(
    proc(e: XEvent) =
      for monitor in this.monitors:
        if monitor.removeWindow(e.xdestroywindow.window):
          monitor.doLayout()
          monitor.ensureWindowFocus(),
      DestroyNotify
  )
  this.eventManager.addListener((e: XEvent) => handleButtonPressed(this, e.xbutton), ButtonPress)
  this.eventManager.addListener((e: XEvent) => handleButtonReleased(this, e.xbutton), ButtonRelease)
  this.eventManager.addListener((e: XEvent) => handleMouseMotion(this, e.xmotion), MotionNotify)

proc openDisplay(): PDisplay =
  let tempDisplay = XOpenDisplay(nil)
  if tempDisplay == nil:
    quit "Failed to open display"
  return tempDisplay

proc configureRootWindow(this: WindowManager): Window =
  result = DefaultRootWindow(this.display)

  var windowAttribs: XSetWindowAttributes
  # Listen for events defined by eventMask.
  # See https://tronche.com/gui/x/xlib/events/processing-overview.html#SubstructureRedirectMask
  windowAttribs.event_mask = SubstructureRedirectMask or PropertyChangeMask or PointerMotionMask

  # Listen for events on the root window
  discard XChangeWindowAttributes(
    this.display,
    result,
    CWEventMask or CWCursor,
    addr(windowAttribs)
  )
  discard XSync(this.display, false)

proc focusMonitor(this: WindowManager, monitorIndex: int) =
  if monitorIndex == -1:
    return
  let monitor = this.monitors[monitorIndex]
  let center = monitor.area.center()
  discard XWarpPointer(
    this.display,
    None,
    this.rootWindow,
    0,
    0,
    0,
    0,
    center.x.cint,
    center.y.cint,
  )

proc focusPreviousMonitor(this: WindowManager) =
  let previousMonitorIndex = this.monitors.findPrevious(this.selectedMonitor)
  this.focusMonitor(previousMonitorIndex)

proc focusNextMonitor(this: WindowManager) =
  let nextMonitorIndex = this.monitors.findNext(this.selectedMonitor)
  this.focusMonitor(nextMonitorIndex)

proc moveClientToMonitor(this: WindowManager, monitorIndex: int) =
  if monitorIndex == -1 or this.selectedMonitor.currClient.isNone:
    return

  let client = this.selectedMonitor.currClient.get
  let nextMonitor = this.monitors[monitorIndex]
  if this.selectedMonitor.removeWindow(client.window):
    this.selectedMonitor.doLayout()
    this.selectedMonitor.ensureWindowFocus()

  nextMonitor.currTagClients.add(client)
  nextMonitor.doLayout()

  if client.isFloating:
    let deltaX = client.x - this.selectedMonitor.area.x
    let deltaY = client.y - this.selectedMonitor.area.y
    this.resize(client,
                nextMonitor.area.x + deltaX,
                nextMonitor.area.y + deltaY,
                client.width,
                client.height)
  elif client.isFullscreen:
    this.resize(client,
                nextMonitor.area.x,
                nextMonitor.area.y,
                nextMonitor.area.width,
                nextMonitor.area.height
               )

  this.selectedMonitor = nextMonitor
  this.focusMonitor(monitorIndex)
  this.selectedMonitor.focusWindow(client.window)

proc moveClientToPreviousMonitor(this: WindowManager) = 
  let previousMonitorIndex = this.monitors.findPrevious(this.selectedMonitor)
  this.moveClientToMonitor(previousMonitorIndex)

proc moveClientToNextMonitor(this: WindowManager) = 
  let nextMonitorIndex = this.monitors.findNext(this.selectedMonitor)
  this.moveClientToMonitor(nextMonitorIndex)

proc increaseMasterCount(this: WindowManager) =
  var layout = this.selectedMonitor.selectedTag.layout
  if layout of MasterStackLayout:
    # This can wrap the uint but the number is crazy high
    # so I don't think it "ruins" the user experience.
    MasterStackLayout(layout).masterSlots.inc
    this.selectedMonitor.doLayout()

proc decreaseMasterCount(this: WindowManager) =
  var layout = this.selectedMonitor.selectedTag.layout
  if layout of MasterStackLayout:
    var masterStackLayout = MasterStackLayout(layout)
    if masterStackLayout.masterSlots > 0:
      masterStackLayout.masterSlots.dec
      this.selectedMonitor.doLayout()

template createControl(keycode: untyped, id: string, action: untyped) =
  this.config.configureAction(id, proc(keycode: int) = action)

proc mapConfigActions*(this: WindowManager) =
  ## Maps available user configuration options to window manager actions.
  createControl(keycode, "increaseMasterCount"):
    this.increaseMasterCount()

  createControl(keycode, "decreaseMasterCount"):
    this.decreaseMasterCount()

  createControl(keycode, "moveWindowToPreviousMonitor"):
    this.moveClientToPreviousMonitor()

  createControl(keycode, "moveWindowToNextMonitor"):
    this.moveClientToNextMonitor()

  createControl(keycode, "focusPreviousMonitor"):
    this.focusPreviousMonitor()

  createControl(keycode, "focusNextMonitor"):
    this.focusNextMonitor()

  createControl(keycode, "goToTag"):
    let tag = this.selectedMonitor.keycodeToTag(keycode)
    this.selectedMonitor.viewTag(tag)

  createControl(keycode, "focusNext"):
    this.selectedMonitor.focusNextClient()

  createControl(keycode, "focusPrevious"):
    this.selectedMonitor.focusPreviousClient()

  createControl(keycode, "moveWindowPrevious"):
    this.selectedMonitor.moveClientPrevious()

  createControl(keycode, "moveWindowNext"):
    this.selectedMonitor.moveClientNext()

  createControl(keycode, "moveWindowToTag"):
    let tag = this.selectedMonitor.keycodeToTag(keycode)
    this.selectedMonitor.moveSelectedWindowToTag(tag)

  createControl(keycode, "toggleFullscreen"):
    this.selectedMonitor.toggleFullscreenForSelectedClient()

  createControl(keycode, "destroySelectedWindow"):
    this.selectedMonitor.destroySelectedWindow()

  createControl(keycode, "toggleFloating"):
    this.selectedMonitor.toggleFloatingForSelectedClient()

proc hookConfigKeys*(this: WindowManager) =
  # Grab key combos defined in the user's config
  for keyCombo in this.config.keyComboTable.keys:
    discard XGrabKey(
      this.display,
      keyCombo.keycode,
      keyCombo.modifiers,
      this.rootWindow,
      true,
      GrabModeAsync,
      GrabModeAsync
    )

  # We only care about left and right clicks
  for button in @[Button1, Button3]: 
    discard XGrabButton(
      this.display,
      button,
      Mod4Mask,
      this.rootWindow,
      false,
      ButtonPressMask or ButtonReleaseMask or PointerMotionMask,
      GrabModeASync,
      GrabModeASync,
      None,
      None
    )

proc errorHandler(display: PDisplay, error: PXErrorEvent): cint{.cdecl.} =
  echo "Error: "
  var errorMessage: string = newString(1024)
  discard XGetErrorText(
    display,
    cint(error.error_code),
    errorMessage.cstring,
    errorMessage.len
  )
  # Reduce string length down to the proper size
  errorMessage.setLen(errorMessage.cstring.len)
  echo "\t", errorMessage

proc onConfigureRequest(this: WindowManager, e: XConfigureRequestEvent) =
  var clientOpt: Option[Client]
  var monitorOpt: Option[Monitor]
  for monitor in this.monitors:
    clientOpt = monitor.find(e.window)
    if clientOpt.isSome:
      monitorOpt = monitor.option
      break
    if monitor.docks.hasKey(e.window):
      clientOpt = monitor.docks[e.window].option
      monitorOpt = monitor.option
      break

  if clientOpt.isSome:
    let client = clientOpt.get
    let monitor = monitorOpt.get
    if (e.value_mask and CWBorderWidth) != 0 and e.border_width > 0:
      discard XSetWindowBorderWidth(this.display, e.window, e.border_width)

    if (e.value_mask and CWX) != 0:
      client.x = e.x
    if (e.value_mask and CWY) != 0:
      client.y = e.y
    if (e.value_mask and CWWidth) != 0:
      client.width = e.width.uint
    if (e.value_mask and CWHeight) != 0:
      client.height = e.height.uint

    if not client.isFixed:
      if client.x == 0:
        client.x = monitor.area.x + (monitor.area.width.int div 2 - (client.width.int div 2))
      if client.y == 0:
        client.y = monitor.area.y + (monitor.area.height.int div 2 - (client.height.int div 2))

    discard XMoveResizeWindow(
      this.display,
      e.window,
      client.x,
      client.y,
      client.width.cint,
      client.height.cint
    )
    this.selectedMonitor.doLayout()
  else: 
    # TODO: Handle xembed windows: https://specifications.freedesktop.org/xembed-spec/xembed-spec-latest.html
    var changes: XWindowChanges
    changes.x = e.detail
    changes.y = e.detail
    changes.width = e.width
    changes.height = e.height
    changes.border_width = e.border_width
    changes.sibling = e.above
    changes.stack_mode = e.detail
    discard XConfigureWindow(this.display, e.window, e.value_mask.cuint, changes.addr)

proc onClientMessage(this: WindowManager, e: XClientMessageEvent) =
  for monitor in this.monitors:
    var clientOpt = monitor.find(e.window)
    if clientOpt.isNone:
      continue
    if e.message_type == $NetWMState:
      let fullscreenAtom = $NetWMStateFullScreen
      if e.data.l[1] == fullscreenAtom or
        e.data.l[2] == fullscreenAtom:
          monitor.toggleFullscreen(clientOpt.get)
    # We can stop once we've found the particular client
    break

proc getProperty[T](
  this: WindowManager,
  window: Window,
  property: Atom,
): Option[T] =
  var
    actualTypeReturn: Atom
    actualFormatReturn: cint
    numItemsReturn: culong
    bytesAfterReturn: culong
    propReturn: ptr T

  discard XGetWindowProperty(
    this.display,
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

proc updateWindowType(this: WindowManager, client: var Client) =
  # NOTE: This is only called for newly created windows,
  # so we don't have to check which monitor it exists on.
  # This should be changed to be more clear in the future.
  let
    stateOpt = this.getProperty[:Atom](client.window, $NetWMState)
    windowTypeOpt = this.getProperty[:Atom](client.window, $NetWMWindowType)
    strutProp = this.getProperty[:Strut](client.window, $NetWMStrutPartial)

  let state = if stateOpt.isSome: stateOpt.get else: None
  let windowType = if windowTypeOpt.isSome: windowTypeOpt.get else: None

  if windowType == $NetWMWindowTypeDock and strutProp.isSome:
    let screenWidth = XDisplayWidth(this.display, XDefaultScreen(this.display))
    let screenHeight = XDisplayHeight(this.display, XDefaultScreen(this.display))
    let area = monitor.calculateStrutArea(strutProp.get, screenWidth, screenHeight)
    client.x = area.x
    client.y = area.y
    client.width = area.width
    client.height = area.height
    client.isFixed = true
    # Find monitor based on location of the dock
    block findMonitorArea:
      for monitor in this.monitors:
        if monitor.area.contains(area.x, area.y):
          monitor.docks.add(client.window, client)
          monitor.updateLayoutOffset()
          discard XMoveResizeWindow(
            this.display,
            client.window,
            client.x,
            client.y,
            client.width.cuint,
            client.height.cuint
          )
          break findMonitorArea
  else:
    this.selectedMonitor.currTagClients.add(client)
    this.selectedMonitor.updateWindowTagAtom(client.window, this.selectedMonitor.selectedTag)

    if state == $NetWMStateFullScreen:
      this.selectedMonitor.toggleFullscreen(client)

    if not client.isFloating:
      client.isFloating = windowType != None and
                          windowType != $NetWMWindowTypeNormal and
                          windowType != $NetWMWindowType

proc updateSizeHints(this: WindowManager, client: var Client) =
  var sizeHints = XAllocSizeHints()
  var returnMask: int
  discard XGetWMNormalHints(this.display, client.window, sizeHints, returnMask.addr)
  if (sizeHints.min_width > 0 and sizeHints.min_width ==
          sizeHints.max_width and sizeHints.min_height > 0 and
          sizeHints.min_height == sizeHints.max_height):
    client.isFloating = true
    client.width = sizeHints.min_width.uint
    client.height = sizeHints.min_height.uint

    if not client.isFixed:
      let area = this.selectedMonitor.area
      client.x = area.x + (area.width.int div 2 - (client.width.int div 2))
      client.y = area.y + (area.height.int div 2 - (client.height.int div 2))
      discard XMoveResizeWindow(this.display,
                                client.window,
                                client.x,
                                client.y,
                                client.width.cuint,
                                client.height.cuint
                               )

proc manage(this: WindowManager, window: Window, windowAttr: XWindowAttributes) =
  # Don't manage the same window twice.
  for monitor in this.monitors:
    if monitor.find(window).isSome:
        return
    if monitor.docks.hasKey(window):
      return

  var client = newClient(window)
  client.x = windowAttr.x
  client.y = windowAttr.y
  client.width = windowAttr.width.uint
  client.height = windowAttr.height.uint

  discard XSetWindowBorder(this.display, window, this.config.borderColorUnfocused)

  discard XSelectInput(this.display,
                       window,
                       StructureNotifyMask or
                       PropertyChangeMask or
                       ResizeRedirectMask or
                       EnterWindowMask or
                       FocusChangeMask)

  this.selectedMonitor.addWindowToClientListProperty(window)

  discard XMoveResizeWindow(this.display,
                            window,
                            client.x,
                            client.y,
                            client.width.cuint,
                            client.height.cuint)

  this.updateWindowType(client)
  this.updateSizeHints(client)
  this.selectedMonitor.doLayout()
  discard XMapWindow(this.display, window)

  if not client.isFixed:
    this.selectedMonitor.focusWindow(window)
  if client.isFloating:
    discard XRaiseWindow(this.display, client.window)

proc onMapRequest(this: WindowManager, e: XMapRequestEvent) =
  var windowAttr: XWindowAttributes
  if XGetWindowAttributes(this.display, e.window, windowAttr.addr) == 0:
    return
  if windowAttr.override_redirect:
    return
  this.manage(e.window, windowAttr)

proc selectCorrectMonitor(this: WindowManager, x, y: int) =
  for monitor in this.monitors:
    if not monitor.area.contains(x, y) or monitor == this.selectedMonitor:
      continue
    let previousMonitor = this.selectedMonitor
    this.selectedMonitor = monitor
    # Set old monitor's focused window's border to the unfocused color
    if previousMonitor.currClient.isSome:
      discard XSetWindowBorder(
        this.display,
        previousMonitor.currClient.get.window,
        this.config.borderColorUnfocused
      )
    # Focus the new monitor's current client
    if this.selectedMonitor.currClient.isSome:
      this.selectedMonitor.focusWindow(this.selectedMonitor.currClient.get.window)
    else:
      discard XSetInputFocus(this.display, this.rootWindow, RevertToPointerRoot, CurrentTime)
    break

proc onMotionNotify(this: WindowManager, e: XMotionEvent) =
  # If moving/resizing a client, we delay selecting the new monitor.
  if this.mouseState == MouseState.Normal:
    this.selectCorrectMonitor(e.x_root, e.y_root)

proc onEnterNotify(this: WindowManager, e: XCrossingEvent) =
  if this.mouseState != MouseState.Normal or e.window == this.rootWindow:
    return
  this.selectCorrectMonitor(e.x_root, e.y_root)
  let clientIndex = this.selectedMonitor.currTagClients.find(e.window)
  if clientIndex >= 0:
    discard XSetInputFocus(this.display, e.window, RevertToPointerRoot, CurrentTime)

proc onFocusIn(this: WindowManager, e: XFocusChangeEvent) =
  if this.mouseState != Normal or
    e.detail == NotifyPointer or
    e.window == this.rootWindow:
    return

  let clientOpt = this.selectedMonitor.find(e.window)
  if clientOpt.isNone:
    return
  
  this.selectedMonitor.setActiveWindowProperty(e.window)

  let client = clientOpt.get
  this.selectedMonitor.selectedTag.setSelectedClient(client)
  discard XSetWindowBorder(
    this.display,
    client.window,
    this.config.borderColorFocused
  )
  if this.selectedMonitor.selectedTag.previouslySelectedClient.isSome:
    let previous = this.selectedMonitor.selectedTag.previouslySelectedClient.get
    if previous.window != client.window:
      discard XSetWindowBorder(
        this.display,
        previous.window,
        this.config.borderColorUnfocused
      )
  if client.isFloating:
    discard XRaiseWindow(this.display, client.window)

proc resize(this: WindowManager, client: Client, x, y: int, width, height: uint) =
  ## Resizes and raises the client.
  client.x = x
  client.y = y
  client.width = width
  client.height = height
  client.adjustToState(this.display)
  discard XRaiseWindow(this.display, client.window)

proc selectClientForMoveResize(this: WindowManager, e: XButtonEvent) =
  if this.selectedMonitor.currClient.isNone:
      return
  let client = this.selectedMonitor.currClient.get
  this.moveResizingClient = client.option
  this.lastMousePress = (e.x.int, e.y.int)
  this.lastMoveResizeClientState = client.toArea()

proc handleButtonPressed(this: WindowManager, e: XButtonEvent) =
  case e.button:
    of Button1:
      this.mouseState = MouseState.Moving
      this.selectClientForMoveResize(e)
    of Button3:
      this.mouseState = MouseState.Resizing
      this.selectClientForMoveResize(e)
    else:
      this.mouseState = MouseState.Normal

proc handleButtonReleased(this: WindowManager, e: XButtonEvent) =
  this.mouseState = MouseState.Normal

  if this.moveResizingClient.isNone:
    return

  # Handle moving clients between monitors
  let client = this.moveResizingClient.get
  # Detect new monitor from area location
  let
    centerX = client.x + client.width.int div 2
    centerY = client.y + client.height.int div 2

  let monitorIndex = this.monitors.find(centerX, centerY)
  if monitorIndex < 0 or this.monitors[monitorIndex] == this.selectedMonitor:
    return
  let nextMonitor = this.monitors[monitorIndex]
  let prevMonitor = this.selectedMonitor
  # Remove client from current monitor/tag
  discard prevMonitor.removeWindow(client.window)
  nextMonitor.currTagClients.add(client)
  nextMonitor.selectedTag.setSelectedClient(client)
  this.selectedMonitor = nextMonitor
  # Unset the client being moved/resized
  this.moveResizingClient = none(Client)

proc handleMouseMotion(this: WindowManager, e: XMotionEvent) =
  if this.mouseState == Normal or this.moveResizingClient.isNone:
    return

  var client = this.moveResizingClient.get
  if client.isFullscreen:
    return

  # Prevent trying to process events too quickly (causes major lag).
  if e.time - this.lastMoveResizeTime < minimumUpdateInterval:
    return

  # Track the last time we moved or resized a window.
  this.lastMoveResizeTime = e.time

  if not client.isFloating:
    client.isFloating = true
    client.borderWidth = this.config.borderWidth.int
    this.selectedMonitor.doLayout()

  let
    deltaX = e.x - this.lastMousePress.x
    deltaY = e.y - this.lastMousePress.y

  if this.mouseState == Moving:
    this.resize(client,
                this.lastMoveResizeClientState.x + deltaX,
                this.lastMoveResizeClientState.y + deltaY,
                this.lastMoveResizeClientState.width,
                this.lastMoveResizeClientState.height)
  elif this.mouseState == Resizing:
    this.resize(client,
                this.lastMoveResizeClientState.x,
                this.lastMoveResizeClientState.y,
                this.lastMoveResizeClientState.width.int + deltaX,
                this.lastMoveResizeClientState.height.int + deltaY)

