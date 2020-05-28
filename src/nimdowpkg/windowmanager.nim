import
  x11 / [x, xlib, xutil, xatom],
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
converter toTBool(x: bool): TBool = x.TBool
converter toBool(x: TBool): bool = x.bool

const
  wmName = "nimdow"
  tagCount = 9

type
  WindowManager* = ref object
    display*: PDisplay
    rootWindow*: TWindow
    eventManager: XEventManager
    config: Config
    monitors: seq[Monitor]
    selectedMonitor: Monitor

proc initListeners(this: WindowManager)
proc openDisplay(): PDisplay
proc mapConfigActions*(this: WindowManager)
proc configureRootWindow(this: WindowManager): TWindow
# XEvents
proc hookConfigKeys*(this: WindowManager)
proc errorHandler(display: PDisplay, error: PXErrorEvent): cint{.cdecl.}
proc onConfigureRequest(this: WindowManager, e: TXConfigureRequestEvent)
proc getProperty[T](
  this: WindowManager,
  window: TWindow,
  property: TAtom
): Option[T]
proc onClientMessage(this: WindowManager, e: TXClientMessageEvent)
proc onMapRequest(this: WindowManager, e: TXMapRequestEvent)
proc onMotionNotify(this: WindowManager, e: TXMotionEvent)
proc onEnterNotify(this: WindowManager, e: TXCrossingEvent)
proc onFocusIn(this: WindowManager, e: TXFocusChangeEvent)

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
  var changes: TXWindowChanges
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
    var text: TXTextProperty
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
  this.eventManager.addListener((e: TXEvent) => onConfigureRequest(this, e.xconfigurerequest), ConfigureRequest)
  this.eventManager.addListener((e: TXEvent) => onClientMessage(this, e.xclient), ClientMessage)
  this.eventManager.addListener((e: TXEvent) => onMapRequest(this, e.xmaprequest), MapRequest)
  this.eventManager.addListener((e: TXEvent) => onMotionNotify(this, e.xmotion), MotionNotify)
  this.eventManager.addListener((e: TXEvent) => onEnterNotify(this, e.xcrossing), EnterNotify)
  this.eventManager.addListener((e: TXEvent) => onFocusIn(this, e.xfocus), FocusIn)
  this.eventManager.addListener(
    proc(e: TXEvent) =
      for monitor in this.monitors:
        monitor.removeWindow(e.xdestroywindow.window),
      DestroyNotify
  )

proc openDisplay(): PDisplay =
  let tempDisplay = XOpenDisplay(nil)
  if tempDisplay == nil:
    quit "Failed to open display"
  return tempDisplay

proc configureRootWindow(this: WindowManager): TWindow =
  result = DefaultRootWindow(this.display)

  var windowAttribs: TXSetWindowAttributes
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
  if this.selectedMonitor.currClient.isNone:
    return

  let client = this.selectedMonitor.currClient.get
  if monitorIndex == -1:
    return

  let nextMonitor = this.monitors[monitorIndex]
  this.selectedMonitor.removeWindowFromTagTable(client.window)
  nextMonitor.currTagClients.add(client)
  nextMonitor.doLayout()
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

proc errorHandler(display: PDisplay, error: PXErrorEvent): cint{.cdecl.} =
  echo "Error: "
  var errorMessage: string = newString(1024)
  discard XGetErrorText(
    display,
    cint(error.error_code),
    errorMessage.cstring,
    len(errorMessage)
  )
  # Reduce string length down to the proper size
  errorMessage.setLen(errorMessage.cstring.len)
  echo "\t", errorMessage

proc onConfigureRequest(this: WindowManager, e: TXConfigureRequestEvent) =
  var clientOpt: Option[Client]
  for monitor in this.monitors:
    clientOpt = monitor.find(e.window)
    if clientOpt.isSome:
      break
    if monitor.docks.hasKey(e.window):
      clientOpt = monitor.docks[e.window].option
      break

  if clientOpt.isSome:
    let client = clientOpt.get
    if (e.value_mask and CWBorderWidth) != 0 and e.border_width > 0:
      discard XSetWindowBorderWidth(this.display, e.window, e.border_width)

    if (e.value_mask and CWX) != 0:
      client.x = e.x
      client.isFloating = true
    if (e.value_mask and CWY) != 0:
      client.y = e.y
      client.isFloating = true
    if (e.value_mask and CWWidth) != 0:
      client.width = e.width.uint
      client.isFloating = true
    if (e.value_mask and CWHeight) != 0:
      client.height = e.height.uint
      client.isFloating = true

    if client.x == -1:
      let screenWidth = XDisplayWidth(this.display, XDefaultScreen(this.display))
      client.x = (screenWidth div 2 - (client.width.int div 2))
    if client.y == -1:
      let screenHeight = XDisplayHeight(this.display, XDefaultScreen(this.display))
      client.y = (screenHeight div 2 - (client.height.int div 2))

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
    var changes: TXWindowChanges
    changes.x = e.detail
    changes.y = e.detail
    changes.width = e.width
    changes.height = e.height
    changes.border_width = e.border_width
    changes.sibling = e.above
    changes.stack_mode = e.detail
    discard XConfigureWindow(this.display, e.window, e.value_mask.cuint, changes.addr)

proc onClientMessage(this: WindowManager, e: TXClientMessageEvent) =
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
  window: TWindow,
  property: TAtom,
): Option[T] =
  var
    actualTypeReturn: TAtom
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

proc updateWindowType(this: WindowManager, window: TWindow) =
  # NOTE: This is only called for newly created windows,
  # so we don't have to check which monitor it exists on.
  # This should be changed to be more clear in the future.
  let
    stateOpt = this.getProperty[:TAtom](window, $NetWMState)
    windowTypeOpt = this.getProperty[:TAtom](window, $NetWMWindowType)
    strutProp = this.getProperty[:Strut](window, $NetWMStrutPartial)

  let state = if stateOpt.isSome: stateOpt.get else: None
  let windowType = if windowTypeOpt.isSome: windowTypeOpt.get else: None

  if windowType == $NetWMWindowTypeDock and strutProp.isSome:
    let screenWidth = XDisplayWidth(this.display, XDefaultScreen(this.display))
    let screenHeight = XDisplayHeight(this.display, XDefaultScreen(this.display))
    let area = monitor.calculateStrutArea(strutProp.get, screenWidth, screenHeight)
    let dock = Client(
      window: window,
      x: area.x,
      y: area.y,
      width: area.width.uint,
      height: area.height.uint
    )
    # Find monitor based on location of the dock
    block findMonitorArea:
      for monitor in this.monitors:
        if monitor.area.contains(area.x, area.y):
          monitor.docks.add(window, dock)
          monitor.updateLayoutOffset()
          discard XMoveResizeWindow(this.display, window, dock.x, dock.y, dock.width.cuint, dock.height.cuint)
          break findMonitorArea
  else:
    var client = newClient(window)
    this.selectedMonitor.currTagClients.add(client)
    this.selectedMonitor.updateWindowTagAtom(client.window, this.selectedMonitor.selectedTag)

    if state == $NetWMStateFullScreen:
      this.selectedMonitor.toggleFullscreen(client)

    client.isFloating = windowType != None and
                        windowType != $NetWMWindowTypeNormal and
                        windowType != $NetWMWindowType

proc manage(this: WindowManager, window: TWindow, windowAttr: TXWindowAttributes) =
  # Don't manage the same window twice.
  for monitor in this.monitors:
    if monitor.find(window).isSome:
        return
    if monitor.docks.hasKey(window):
      return

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
                            windowAttr.x,
                            windowAttr.y,
                            windowAttr.width,
                            windowAttr.height)

  this.updateWindowType(window)
  this.selectedMonitor.doLayout()
  discard XMapWindow(this.display, window)

  # Ensure this window isn't a dock before requesting focus
  var isDock = false
  for monitor in this.monitors:
    if monitor.docks.hasKey(window):
      isDock = true
      break
  if not isDock:
    this.selectedMonitor.focusWindow(window)

proc onMapRequest(this: WindowManager, e: TXMapRequestEvent) =
  var windowAttr: TXWindowAttributes
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
    break

proc onMotionNotify(this: WindowManager, e: TXMotionEvent) =
  this.selectCorrectMonitor(e.x_root, e.y_root)

proc onEnterNotify(this: WindowManager, e: TXCrossingEvent) =
  if e.window != this.rootWindow:
    this.selectCorrectMonitor(e.x_root, e.y_root)
    let clientIndex = this.selectedMonitor.currTagClients.find(e.window)
    if clientIndex >= 0:
      discard XSetInputFocus(this.display, e.window, RevertToPointerRoot, CurrentTime)

proc onFocusIn(this: WindowManager, e: TXFocusChangeEvent) =
  if e.detail == NotifyPointer or
    e.window == this.rootWindow:
    return

  let clientIndex = this.selectedMonitor.currTagClients.find(e.window)
  if clientIndex < 0:
    return
  
  this.selectedMonitor.setActiveWindowProperty(e.window)

  let client = this.selectedMonitor.currTagClients[clientIndex]
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

