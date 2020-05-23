import
  x11 / [x, xlib, xutil, xatom],
  sugar,
  options,
  tables,
  sets,
  client,
  xatoms,
  monitor,
  tag,
  area,
  config/config,
  event/xeventmanager

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
  borderColorFocused = 0x519f50
  borderColorUnfocused = 0x1c1b19

type
  WindowManager* = ref object
    display*: PDisplay
    rootWindow*: TWindow
    eventManager: XEventManager
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
proc getProperty[T](this: WindowManager, window: TWindow, property: TAtom, kind: typedesc[T]): Option[T]
proc onClientMessage(this: WindowManager, e: TXClientMessageEvent)
proc onMapRequest(this: WindowManager, e: TXMapRequestEvent)
proc onMotionNotify(this: WindowManager, e: TXMotionEvent)
proc onEnterNotify(this: WindowManager, e: TXCrossingEvent)
proc onFocusIn(this: WindowManager, e: TXFocusChangeEvent)

proc newWindowManager*(eventManager: XEventManager): WindowManager =
  result = WindowManager()
  result.display = openDisplay()
  result.rootWindow = result.configureRootWindow()
  result.eventManager = eventManager
  # Populate atoms
  xatoms.WMAtoms = xatoms.getWMAtoms(result.display)
  xatoms.NetAtoms = xatoms.getNetAtoms(result.display)
  xatoms.XAtoms = xatoms.getXAtoms(result.display)
  result.initListeners()

  # Create monitors
  for area in result.display.getMonitorAreas(result.rootWindow):
    result.monitors.add(
      newMonitor(result.display, result.rootWindow, area)
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
    (e: TXEvent) =>
      this.selectedMonitor.removeWindow(e.xdestroywindow.window),
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

template config(keycode: untyped, id: string, action: untyped) =
  config.configureAction(id, proc(keycode: int) = action)

proc mapConfigActions*(this: WindowManager) =
  ## Maps available user configuration options to window manager actions.
  config(keycode, "goToTag"):
    let tag = this.selectedMonitor.keycodeToTag(keycode)
    this.selectedMonitor.viewTag(tag)

  config(keycode, "focusNext"):
    this.selectedMonitor.focusNextClient()

  config(keycode, "focusPrevious"):
    this.selectedMonitor.focusPreviousClient()

  config(keycode, "moveWindowPrevious"):
    this.selectedMonitor.moveClientPrevious()

  config(keycode, "moveWindowNext"):
    this.selectedMonitor.moveClientNext()

  config(keycode, "moveWindowToTag"):
    let tag = this.selectedMonitor.keycodeToTag(keycode)
    this.selectedMonitor.moveSelectedWindowToTag(tag)

  config(keycode, "toggleFullscreen"):
    this.selectedMonitor.toggleFullscreenForSelectedClient()

  config(keycode, "destroySelectedWindow"):
    this.selectedMonitor.destroySelectedWindow()

proc hookConfigKeys*(this: WindowManager) =
  # Grab key combos defined in the user's config
  for keyCombo in config.KeyComboTable.keys:
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
  for monitor in this.monitors:
    # TODO: Handle docks as well?
    var clientOpt: Option[Client] = none(Client)
    for tag, clients in monitor.taggedClients.pairs:
      let index = clients.find(e.window)
      if index >= 0:
        clientOpt = clients[index].option
        break

    if clientOpt.isSome:
      let client = clientOpt.get
      var geometry: Area 

      if (e.value_mask and CWBorderWidth) != 0:
        discard XSetWindowBorderWidth(this.display, client.window, e.border_width)

      # Geom
      if (e.value_mask and CWWidth) != 0:
        geometry.width = e.width.uint
      if (e.value_mask and CWHeight) != 0:
        geometry.height = e.height.uint
      if (e.value_mask and CWX) != 0:
        geometry.x = e.x
      if (e.value_mask and CWY) != 0:
        geometry.y = e.y
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
  if e.message_type == $NetWMStrutPartial:
    discard

  for monitor in this.monitors:
    var clientOpt = monitor.find(e.window)
    if clientOpt.isNone:
      return
    if e.message_type == $NetWMState:
      let fullscreenAtom = $NetWMStateFullScreen
      if e.data.l[1] == fullscreenAtom or
        e.data.l[2] == fullscreenAtom:
          monitor.toggleFullscreen(clientOpt.get)
    # We can stop once we've found the particular client
    break

proc getProperty[T](this: WindowManager, window: TWindow, property: TAtom, kind: typedesc[T]): Option[T] =
  var
    actualTypeReturn: TAtom
    actualFormatReturn: cint
    numItemsReturn: culong
    bytesAfterReturn: culong
    propReturn: ptr T

  let getPropResult = XGetWindowProperty(
    this.display,
    window,
    property,
    0,
    sizeof(T) div 4,
    false,
    AnyPropertyType,
    actualTypeReturn.addr,
    actualFormatReturn.addr,
    numItemsReturn.addr,
    bytesAfterReturn.addr,
    cast[PPcuchar](propReturn.addr)
  )

  if getPropResult == Success and propReturn != nil:
    return option(propReturn[])
  return none(T)

proc updateWindowType(this: WindowManager, window: TWindow, windowAttr: TXWindowAttributes) =
  # NOTE: This is only called for newly created windows,
  # so we don't have to check which monitor it exists on.
  # This should be changed to be more clear in the future.
  let
    stateOpt = this.getProperty(window, $NetWMState, TAtom)
    windowTypeOpt = this.getProperty(window, $NetWMWindowType, TAtom)

  let state: TAtom = if stateOpt.isSome: stateOpt.get else: None
  let windowType: TAtom = if windowTypeOpt.isSome: windowTypeOpt.get else: None

  if windowType == $NetWMWindowTypeDock:
      let dock = Dock(
        window: window,
        x: windowAttr.x,
        y: windowAttr.y,
        width: windowAttr.width.uint,
        height: windowAttr.height.uint
      )
      this.selectedMonitor.docks.add(window, dock)
      this.selectedMonitor.updateLayoutOffset()
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

  discard XSetWindowBorder(this.display, window, borderColorUnfocused)

  discard XSelectInput(this.display,
                       window,
                       StructureNotifyMask or
                       PropertyChangeMask or
                       ResizeRedirectMask or
                       EnterWindowMask or
                       FocusChangeMask)

  discard XRaiseWindow(this.display, window)

  this.selectedMonitor.addWindowToClientListProperty(window)

  discard XMoveResizeWindow(this.display,
                            window,
                            windowAttr.x,
                            windowAttr.y,
                            windowAttr.width,
                            windowAttr.height)

  this.updateWindowType(window, windowAttr)
  this.selectedMonitor.doLayout()
  discard XMapWindow(this.display, window)
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
    if monitor.area.contains(x, y):
      if monitor != this.selectedMonitor:
        this.selectedMonitor = monitor
      break

proc onMotionNotify(this: WindowManager, e: TXMotionEvent) =
  this.selectCorrectMonitor(e.x_root, e.y_root)

proc onEnterNotify(this: WindowManager, e: TXCrossingEvent) =
  if e.window != this.rootWindow:
    this.selectCorrectMonitor(e.x_root, e.y_root)
    let clientIndex = this.selectedMonitor.currTagClients.find(e.window)
    if clientIndex >= 0 and this.selectedMonitor.currTagClients[clientIndex].isNormal:
      # Only focus normal windows
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
    borderColorFocused
  )
  if this.selectedMonitor.selectedTag.previouslySelectedClient.isSome:
    let previous = this.selectedMonitor.selectedTag.previouslySelectedClient.get
    if previous.window != client.window:
      discard XSetWindowBorder(
        this.display,
        previous.window,
        borderColorUnfocused
      )

