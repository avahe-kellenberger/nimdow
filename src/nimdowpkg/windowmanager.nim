import
  x11 / [x, xlib, xutil, xatom, xft],
  parsetoml,
  math,
  tables,
  sets,
  taggedclients,
  xatoms,
  monitor,
  statusbar,
  systray,
  strutils,
  parseutils,
  tag,
  area,
  point,
  config / [apprules, configloader],
  event/xeventmanager,
  layouts/masterstacklayout,
  keys/keyutils,
  logger,
  utils,
  listutils,
  deques,
  wmcommands

converter intToCint(x: int): cint = x.cint
converter intToCUint(x: int): cuint = x.cuint
converter uintToCuing(x: uint): cuint = x.cuint
converter cintToUint(x: cint): uint = x.uint
converter cintToCUint(x: cint): cuint = x.cuint
converter intToCUchar(x: int): cuchar = x.cuchar
converter clongToCUlong(x: clong): culong = x.culong
converter toXBool(x: bool): XBool = x.XBool
converter toBool(x: XBool): bool = x.bool

const
  wmName = "nimdow"
  minimumUpdateInterval = math.round(1000 / 60).int

  systrayMonitorID = 1
  STATUS_MONITOR_PREFIX = "NIMDOW_MONITOR_INDEX="

  SYSTEM_TRAY_REQUEST_DOCK = 0

  XEMBED_EMBEDDED_NOTIFY = 0
  XEMBED_MAPPED = 1 shl 0
  XEMBED_WINDOW_ACTIVATE = 1
  XEMBED_WINDOW_DEACTIVATE = 2

  VERSION_MAJOR = 0
  VERSION_MINOR = 0
  XEMBED_EMBEDDED_VERSION = (VERSION_MAJOR shl 16) or VERSION_MINOR

  MOUSE_MASK = ButtonPressMask or ButtonReleaseMask or PointerMotionMask

type
  MouseAction* {.pure.} = enum
    Normal, Moving, Resizing
  WindowManager* = ref object
    display*: PDisplay
    rootWindow*: Window
    rootWindowWidth: int
    rootWindowHeight: int
    systray: Systray
    eventManager: XEventManager
    config: Config
    windowSettings: WindowSettings
    monitors: OrderedTable[MonitorID, Monitor]
    selectedMonitor: Monitor
    mouseAction: MouseAction
    lastMousePress: Point[int]
    lastMoveResizeClientState: Area
    lastMoveResizeTime: culong
    moveResizingClient: Client
    scratchpad: Deque[Client]

proc initListeners(this: WindowManager)
proc openDisplay(): PDisplay
proc mapConfigActions*(this: WindowManager)
proc configureRootWindow(this: WindowManager): Window
proc grabKeys*(this: WindowManager)
proc grabButtons*(this: WindowManager, client: Client, focused: bool)
proc errorHandler(display: PDisplay, error: PXErrorEvent): cint{.cdecl.}
proc focus*(this: WindowManager, client: Client, warpToClient: bool)
proc unfocus*(this: WindowManager, client: Client)
proc destroySelectedWindow*(this: WindowManager)
proc onConfigureRequest(this: WindowManager, e: XConfigureRequestEvent)
proc onConfigureNotify(this: WindowManager, e: XConfigureEvent)
proc onClientMessage(this: WindowManager, e: XClientMessageEvent)
proc onMapRequest(this: WindowManager, e: XMapRequestEvent)
proc onUnmapNotify(this: WindowManager, e: XUnmapEvent)
proc onMappingNotify(this: WindowManager, e: XMappingEvent)
proc onResizeRequest(this: WindowManager, e: XResizeRequestEvent)
proc onMotionNotify(this: WindowManager, e: XMotionEvent)
proc onEnterNotify(this: WindowManager, e: XCrossingEvent)
proc onFocusIn(this: WindowManager, e: XFocusChangeEvent)
proc onPropertyNotify(this: WindowManager, e: XPropertyEvent)
proc onExposeNotify(this: WindowManager, e: XExposeEvent)
proc onDestroyNotify(this: WindowManager, e: XDestroyWindowEvent)
proc handleButtonPressed(this: WindowManager, e: XButtonEvent)
proc handleButtonReleased(this: WindowManager, e: XButtonEvent)
proc handleMouseMotion(this: WindowManager, e: XMotionEvent)
proc renderStatus(this: WindowManager)
proc setSelectedMonitor(this: WindowManager, monitor: Monitor)
proc unmanage(this: WindowManager, window: Window, destroyed: bool)
proc updateSizeHints(this: WindowManager, client: var Client, monitor: Monitor)
proc updateSystray(this: WindowManager)
proc updateSystrayIconGeom(this: WindowManager, icon: Icon, width, height: int)
proc updateSystrayIconState(this: WindowManager, icon: Icon, e: XPropertyEvent)
proc windowToClient(
  this: WindowManager,
  window: Window
): tuple[client: Client, monitor: Monitor]
proc windowToMonitor(this: WindowManager, window: Window): Monitor

proc newWindowManager*(
  eventManager: XEventManager,
  config: Config,
  configTable: TomlTable
): WindowManager =
  result = WindowManager()
  result.display = openDisplay()
  result.rootWindow = result.configureRootWindow()
  result.rootWindowWidth = DisplayWidth(result.display, DefaultScreen(result.display))
  result.rootWindowHeight = DisplayHeight(result.display, DefaultScreen(result.display))
  result.eventManager = eventManager
  discard XSetErrorHandler(errorHandler)

  # Config setup
  try:
    result.config = config
    result.mapConfigActions()
    result.config.populateKeyComboTable(configTable, result.display)
    result.config.populateGeneralSettings(configTable)
    result.config.hookConfig()
    result.grabKeys()
  except:
    log getCurrentExceptionMsg(), lvlError

  result.windowSettings = result.config.windowSettings
  # Populate atoms
  xatoms.WMAtoms = xatoms.getWMAtoms(result.display)
  xatoms.NetAtoms = xatoms.getNetAtoms(result.display)
  xatoms.XAtoms = xatoms.getXAtoms(result.display)
  result.initListeners()

  # Create monitors
  for i, area in result.display.getMonitorAreas(result.rootWindow):
    let id: MonitorID = i + 1
    result.monitors[id] =
      newMonitor(id, result.display, result.rootWindow, area, result.config)

  result.renderStatus()

  # Supporting window for NetWMCheck
  let ewmhWindow = XCreateSimpleWindow(result.display, result.rootWindow, 0, 0, 1, 1, 0, 0, 0)

  discard XChangeProperty(
    result.display,
    result.rootWindow,
    $NetSupportingWMCheck,
    XA_WINDOW,
    32,
    PropModeReplace,
    cast[Pcuchar](ewmhWindow.unsafeAddr),
    1
  )

  discard XChangeProperty(
    result.display,
    ewmhWindow,
    $NetSupportingWMCheck,
    XA_WINDOW,
    32,
    PropModeReplace,
    cast[Pcuchar](ewmhWindow.unsafeAddr),
    1
  )

  discard XChangeProperty(
    result.display,
    ewmhWindow,
    $NetWMName,
    XInternAtom(result.display, "UTF8_STRING", false),
    8,
    PropModeReplace,
    cast[Pcuchar](wmName),
    wmName.len
  )

  discard XChangeProperty(
    result.display,
    result.rootWindow,
    $NetWMName,
    XInternAtom(result.display, "UTF8_STRING", false),
    8,
    PropModeReplace,
    cast[Pcuchar](wmName),
    wmName.len
  )

  discard XChangeProperty(
    result.display,
    result.rootWindow,
    $NetSupported,
    XA_ATOM,
    32,
    PropModeReplace,
    cast[Pcuchar](xatoms.NetAtoms.unsafeAddr),
    ord(NetLast)
  )

  # We need to map this window to be able to set the input focus to it
  # when no other window is available to be focused.
  discard XMapWindow(result.display, ewmhWindow)
  var changes: XWindowChanges
  changes.stack_mode = Below
  discard XConfigureWindow(result.display, ewmhWindow, CWStackMode, addr(changes))

  block setNumberOfDesktops:
    let data: array[1, clong] = [9]
    discard XChangeProperty(
      result.display,
      result.rootWindow,
      $NetNumberOfDesktops,
      XA_CARDINAL,
      32,
      PropModeReplace,
      cast[Pcuchar](data.unsafeAddr),
      1
    )

  block setDesktopNames:
    var tags: array[tagCount, cstring] = [
      "1".cstring,
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9"
    ]
    var text: XTextProperty
    discard Xutf8TextListToTextProperty(
      result.display,
      cast[PPChar](tags[0].addr),
      tagCount,
      XUTF8StringStyle,
      text.unsafeAddr
    )
    XSetTextProperty(result.display,
      result.rootWindow,
      text.unsafeAddr,
      $NetDesktopNames
    )

  block setDesktopViewport:
    var data = newSeq[seq[clong]]()
    for monitor in result.monitors.values():
      data.add(
        @[monitor.area.x.clong, monitor.area.y.clong]
      )

    discard XChangeProperty(
      result.display,
      result.rootWindow,
      $NetDesktopViewport,
      XA_CARDINAL,
      32,
      PropModeReplace,
      cast[Pcuchar](data.unsafeAddr),
      data.len
    )

  result.mouseAction = MouseAction.Normal

  result.setSelectedMonitor(result.monitors[1])
  result.updateSystray()

template selectedMonitorConfig(this: WindowManager): MonitorSettings =
  if this.config.monitorSettings.hasKey(this.selectedMonitor.id):
    this.config.monitorSettings[this.selectedMonitor.id]
  else:
    this.config.defaultMonitorSettings

template systrayMonitor(this: WindowManager): Monitor =
  this.monitors[systrayMonitorID]

proc reloadConfig*(this: WindowManager) =
  # Remove old config listener.
  this.eventManager.removeListener(this.config.xEventListener, KeyPress)

  let
    oldConfig = this.config
    oldLoggingEnabled = logger.enabled

  this.config = newConfig(this.eventManager)

  try:
    let configTable = configloader.loadConfigFile()
    this.config.populateAppRules(configTable)
    this.mapConfigActions()
    this.config.populateKeyComboTable(configTable, this.display)
    this.config.populateGeneralSettings(configTable)
    logger.enabled = this.config.loggingEnabled
  except:
    logger.enabled = oldLoggingEnabled
    # If the config fails to load, restore the old config.
    this.config = oldConfig
    log getCurrentExceptionMsg(), lvlError

  this.config.hookConfig()
  this.grabKeys()

  this.windowSettings = this.config.windowSettings
  for monitor in this.monitors.mvalues():
    monitor.setConfig(this.config)
    monitor.redrawStatusBar()

  this.updateSystray()

template onEvent(theType: int, e, body: untyped): untyped =
  this.eventManager.addListener(
    (proc (event: XEvent) =
      let e: XEvent = event
      body
    ),
    theType
  )

proc initListeners(this: WindowManager) =
  onEvent(ConfigureRequest, e): this.onConfigureRequest(e.xconfigurerequest)
  onEvent(ConfigureNotify, e): this.onConfigureNotify(e.xconfigure)
  onEvent(ClientMessage, e): this.onClientMessage(e.xclient)
  onEvent(MapRequest, e): this.onMapRequest(e.xmaprequest)
  onEvent(UnmapNotify, e): this.onUnmapNotify(e.xunmap)
  onEvent(MappingNotify, e): this.onMappingNotify(e.xmapping)
  onEvent(ResizeRequest, e): this.onResizeRequest(e.xresizerequest)
  onEvent(MotionNotify, e): this.onMotionNotify(e.xmotion)
  onEvent(EnterNotify, e): this.onEnterNotify(e.xcrossing)
  onEvent(FocusIn, e): this.onFocusIn(e.xfocus)
  onEvent(PropertyNotify, e): this.onPropertyNotify(e.xproperty)
  onEvent(Expose, e): this.onExposeNotify(e.xexpose)
  onEvent(DestroyNotify, e): this.onDestroyNotify(e.xdestroywindow)
  onEvent(ButtonPress, e): this.handleButtonPressed(e.xbutton)
  onEvent(ButtonRelease, e): this.handleButtonReleased(e.xbutton)

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
  windowAttribs.event_mask =
    StructureNotifyMask or
    SubstructureRedirectMask or
    PropertyChangeMask or
    PointerMotionMask

  # Listen for events on the root window
  discard XChangeWindowAttributes(
    this.display,
    result,
    CWEventMask or CWCursor,
    addr(windowAttribs)
  )
  discard XSync(this.display, false)

proc findRelativeTag(this: WindowManager, offset: int): Tag =
  let selectedTag = this.selectedMonitor.taggedClients.findFirstSelectedTag
  if selectedTag.isNil:
    return

  var tagNumber = abs((selectedTag.id + offset) mod this.selectedMonitor.tags.len)
  if tagNumber <= 0:
    tagNumber = this.selectedMonitor.tags.len
  return this.selectedMonitor.tags[tagNumber - 1]

template findLeftTag(this: WindowManager): Tag =
  this.findRelativeTag(-1)

template findRightTag(this: WindowManager): Tag =
  this.findRelativeTag(1)

proc focusMonitor(this: WindowManager, monitorIndex: int) =
  let monitorID = monitorIndex + 1
  if not this.monitors.hasKey(monitorID):
    return

  var monitor = this.monitors[monitorID]

  if monitor.taggedClients.currClient == nil:
    let center = monitor.area.center()
    discard XWarpPointer(
      this.display,
      x.None,
      this.rootWindow,
      0,
      0,
      0,
      0,
      center.x.cint,
      center.y.cint,
    )
  else:
    monitor.taggedClients.withSomeCurrClient(c):
      this.display.warpTo(c)

proc focusPreviousMonitor(this: WindowManager) =
  let previousMonitorIndex = this.monitors.valuesToSeq().findPrevious(this.selectedMonitor)
  this.focusMonitor(previousMonitorIndex)

proc focusNextMonitor(this: WindowManager) =
  let nextMonitorIndex = this.monitors.valuesToSeq().findNext(this.selectedMonitor)
  this.focusMonitor(nextMonitorIndex)

proc setSelectedMonitor(this: WindowManager, monitor: Monitor) =
  ## Sets the selected monitor.
  ## This should be called, NEVER directly assign this.selectedMonitor.
  if this.selectedMonitor != nil:
    this.selectedMonitor.statusBar.setIsMonitorSelected(false)

  this.selectedMonitor = monitor
  this.selectedMonitor.statusBar.setIsMonitorSelected(true)

proc moveClientToMonitor(this: WindowManager, client: var Client, monitorIndex: int) =
  let monitorID = monitorIndex + 1
  if not this.monitors.hasKey(monitorID):
    return

  let startMonitor = this.selectedMonitor

  this.setSelectedMonitor(this.monitors[monitorID])

  if startMonitor.removeWindow(client.window):
    startMonitor.doLayout(false)

  # Add client to all selected tags
  this.selectedMonitor.addClient(client)

  if client.isFullscreen:
    client.resize(
      this.display,
      this.selectedMonitor.area.x,
      this.selectedMonitor.area.y,
      this.selectedMonitor.area.width,
      this.selectedMonitor.area.height
    )
    this.selectedMonitor.doLayout(false)
  elif client.isFloating:
    let deltaX = client.x - startMonitor.area.x
    let deltaY = client.y - startMonitor.area.y
    client.resize(
      this.display,
      this.selectedMonitor.area.x + deltaX,
      this.selectedMonitor.area.y + deltaY,
      client.width,
      client.height
    )
  else:
    this.selectedMonitor.doLayout(false)

  this.focus(client, true)

proc moveSelectedClientToMonitor(this: WindowManager, monitorIndex: int) =
  var client = this.selectedMonitor.taggedClients.currClient
  if client == nil:
    return
  this.moveClientToMonitor(client, monitorIndex)

proc moveClientToPreviousMonitor(this: WindowManager) =
  let previousMonitorIndex = this.monitors.valuesToSeq().findPrevious(this.selectedMonitor)
  this.moveSelectedClientToMonitor(previousMonitorIndex)

proc moveClientToNextMonitor(this: WindowManager) =
  let nextMonitorIndex = this.monitors.valuesToSeq().findNext(this.selectedMonitor)
  this.moveSelectedClientToMonitor(nextMonitorIndex)

proc increaseMasterCount(this: WindowManager) =
  let firstSelectedTag = this.selectedMonitor.taggedClients.findFirstSelectedTag()
  if firstSelectedTag == nil:
    return

  var layout = firstSelectedTag.layout
  if layout of MasterStackLayout:
    # This can wrap the uint but the number is crazy high
    # so I don't think it "ruins" the user experience.
    MasterStackLayout(layout).masterSlots.inc
    this.selectedMonitor.doLayout()

proc decreaseMasterCount(this: WindowManager) =
  let firstSelectedTag = this.selectedMonitor.taggedClients.findFirstSelectedTag()
  if firstSelectedTag == nil:
    return

  var layout = firstSelectedTag.layout
  if layout of MasterStackLayout:
    var masterStackLayout = MasterStackLayout(layout)
    if masterStackLayout.masterSlots.int > 0:
      masterStackLayout.masterSlots.dec
      this.selectedMonitor.doLayout()

proc goToTag(this: WindowManager, tagID: TagID, warpToClient: bool = true) =
  # Check if only the same tag is shown
  let selectedTags = this.selectedMonitor.selectedTags

  var destTag = tagID
  if selectedTags.len == 1:
    # Find the only selected tag
    var selectedTag: TagID
    for tag in selectedTags:
      selectedTag = tag
      break

    # If attempting to select the same single tag, view the previous tag instead.
    if this.selectedMonitor.previousTagID != 0 and selectedTag == destTag:
      # Change the tag ID which is used later.
      destTag = this.selectedMonitor.previousTagID

    # Swap the previous tag.
    this.selectedMonitor.previousTagID = selectedTag

  this.selectedMonitor.setSelectedTags(destTag, warpToClient)

  if warpToClient:
    this.selectedMonitor.taggedClients.withSomeCurrClient(client):
      this.display.warpTo(client)

proc jumpToUrgentWindow(this: WindowManager) =
  var
    urgentClient: Client
    urgentMonitor: Monitor

  # Find the first urgent window.
  for monitor in this.monitors.values():
    for client in monitor.taggedClients.clientSelection:
      if client.isUrgent:
        urgentClient = client
        urgentMonitor = monitor
        break

  if urgentClient == nil:
    # There are no urgent clients.
    return

  if urgentClient.tagIDs.len < 1:
    # Should never happen.
    return

  # Find the first tag.
  var tagID: TagID
  for id in urgentClient.tagIDs:
    tagID = id
    break

  # Check if any tags the urgentClient is on is in the set of selected tags.
  var isClientVisible = false
  for id in urgentClient.tagIDs:
    if urgentMonitor.selectedTags.contains(id):
      isClientVisible = true
      break

  if not isClientVisible:
    # Set the previousTag.
    for id in urgentMonitor.taggedClients.selectedTags:
      urgentMonitor.previousTagID = id
      break

  urgentMonitor.setSelectedTags(tagID)
  this.display.warpTo(urgentClient)

template modWidthDiff(this: WindowManager, diff: int) =
  var layout = this.selectedMonitor.taggedClients.findFirstSelectedTag.layout
  if layout of MasterStackLayout:
    let masterStackLayout = cast[MasterStackLayout](layout)
    let screenWidth = masterStackLayout.calcScreenWidth(this.selectedMonitor.layoutOffset)

    if
      (diff > 0 and masterStackLayout.widthDiff < 0) or
      (diff < 0 and masterStackLayout.widthDiff > 0) or
      masterStackLayout.calcClientWidth(screenWidth).int - abs(masterStackLayout.widthDiff).int - abs(
          diff).int > 0:
        masterStackLayout.widthDiff += diff
        this.selectedMonitor.doLayout()

proc increaseMasterWidth(this: WindowManager) =
  this.modWidthDiff(this.selectedMonitor.monitorSettings.layoutSettings.resizeStep.int)

proc decreaseMasterWidth(this: WindowManager) =
  this.modWidthDiff(-this.selectedMonitor.monitorSettings.layoutSettings.resizeStep.int)

proc moveWindowToScratchpad(this: WindowManager) =
  var client = this.selectedMonitor.taggedClients.currClient
  if client != nil:
    client.tagIDs.clear()
    this.selectedMonitor.doLayout(false)
    discard this.selectedMonitor.removeWindow(client.window)
    this.scratchpad.addLast(client)

proc popScratchpad(this: WindowManager) =
  var client: Client
  try:
    client = this.scratchpad.popLast()
  except IndexDefect:
    return

  # After popping, only have it on the selectedMonitor and selected tags
  var selectedMonitorIndex: MonitorID = -1
  for id, monitor in this.monitors.pairs():
    if monitor == this.selectedMonitor:
      selectedMonitorIndex = id - 1
      break
  if selectedMonitorIndex < 0:
    return

  # Normal window
  if not client.isFullscreen and not client.isFloating and not client.isFixedSize:
    let
      width = this.config.scratchpadSettings.width
      height = this.config.scratchpadSettings.height

    client.resize(
      this.display,
      this.selectedMonitor.area.x + (this.selectedMonitor.area.width.int - width) div 2,
      this.selectedMonitor.area.y + (this.selectedMonitor.area.height.int - height) div 2,
      width,
      height
    )

    client.isFloating = true
    this.moveClientToMonitor(client, selectedMonitorIndex)
  else:
    # Floating/fullscreen/etc
    client.x = this.selectedMonitor.area.x +
               (this.selectedMonitor.area.width.int - client.width.int) div 2
    client.y = this.selectedMonitor.area.y +
               (this.selectedMonitor.area.height.int - client.height.int) div 2
    this.moveClientToMonitor(client, selectedMonitorIndex)

  this.selectedMonitor.doLayout(true)

template createControl(keyCombo: untyped, id: string, action: untyped) =
  this.config.configureAction(id, proc(keyCombo: KeyCombo) = action)

proc mapConfigActions*(this: WindowManager) =
  ## Maps available user configuration options to window manager actions.
  createControl(keyCombo, $wmcReloadConfig):
    this.reloadConfig()

  createControl(keyCombo, $wmcIncreaseMasterCount):
    this.increaseMasterCount()

  createControl(keyCombo, $wmcDecreaseMasterCount):
    this.decreaseMasterCount()

  createControl(keyCombo, $wmcMoveWindowToPreviousMonitor):
    this.moveClientToPreviousMonitor()

  createControl(keyCombo, $wmcMoveWindowToNextMonitor):
    this.moveClientToNextMonitor()

  createControl(keyCombo, $wmcFocusPreviousMonitor):
    this.focusPreviousMonitor()

  createControl(keyCombo, $wmcFocusNextMonitor):
    this.focusNextMonitor()

  createControl(keyCombo, $wmcGoToTag):
    var tagIDOpt = this.selectedMonitor.keycodeToTagID(keyCombo.keycode)
    if tagIDOpt.isSome:
      this.goToTag(tagIDOpt.get)

  createControl(keyCombo, $wmcGoToLeftTag):
    let leftTag = this.findLeftTag()
    if leftTag != nil:
      this.goToTag(leftTag.id)

  createControl(keyCombo, $wmcGoToRightTag):
    let rightTag = this.findRightTag()
    if rightTag != nil:
      this.goToTag(rightTag.id)

  createControl(keyCombo, $wmcGoToPreviousTag):
    var previousTag = this.selectedMonitor.previousTagID
    if previousTag != 0:
      this.goToTag(previousTag)

  createControl(keyCombo, $wmcMoveWindowToPreviousTag):
    var previousTagID = this.selectedMonitor.previousTagID
    if previousTagID != 0:
      this.selectedMonitor.moveSelectedWindowToTag(previousTagID)

  createControl(keyCombo, $wmcToggleTagView):
    let tagIDOpt = this.selectedMonitor.keycodeToTagID(keyCombo.keycode)
    if tagIDOpt.isSome:
      this.selectedMonitor.toggleTags(tagIDOpt.get)

  createControl(keyCombo, $wmcToggleWindowTag):
    this.selectedMonitor.taggedClients.withSomeCurrClient(client):
      let tagIDOpt = this.selectedMonitor.keycodeToTagID(keyCombo.keycode)
      if tagIDOpt.isSome:
        this.selectedMonitor.toggleTagsForClient(client, tagIDOpt.get)

  createControl(keyCombo, $wmcFocusNext):
    this.selectedMonitor.focusNextClient(true)
    this.selectedMonitor.taggedClients.withSomeCurrClient(client):
      this.focus(client, false)

  createControl(keyCombo, $wmcFocusPrevious):
    this.selectedMonitor.focusPreviousClient(true)
    this.selectedMonitor.taggedClients.withSomeCurrClient(client):
      this.focus(client, false)

  createControl(keyCombo, $wmcMoveWindowPrevious):
    this.selectedMonitor.moveClientPrevious()

  createControl(keyCombo, $wmcMoveWindowNext):
    this.selectedMonitor.moveClientNext()

  createControl(keyCombo, $wmcMoveWindowToTag):
    let tagIDOpt = this.selectedMonitor.keycodeToTagID(keyCombo.keycode)
    if tagIDOpt.isSome:
      this.selectedMonitor.moveSelectedWindowToTag(tagIDOpt.get)

  createControl(keyCombo, $wmcMoveWindowToLeftTag):
    let leftTag = this.findLeftTag()
    if leftTag != nil:
      this.selectedMonitor.moveSelectedWindowToTag(leftTag.id)

  createControl(keyCombo, $wmcMoveWindowToRightTag):
    let rigthTag = this.findRightTag()
    if rigthTag != nil:
      this.selectedMonitor.moveSelectedWindowToTag(rigthTag.id)

  createControl(keyCombo, $wmcToggleFullscreen):
    this.selectedMonitor.toggleFullscreenForSelectedClient()

  createControl(keyCombo, $wmcDestroySelectedWindow):
    this.destroySelectedWindow()

  createControl(keyCombo, $wmcToggleFloating):
    this.selectedMonitor.toggleFloatingForSelectedClient()

  createControl(keyCombo, $wmcJumpToUrgentWindow):
    this.jumpToUrgentWindow()

  createControl(keyCombo, $wmcIncreaseMasterWidth):
    this.increaseMasterWidth()

  createControl(keyCombo, $wmcDecreaseMasterWidth):
    this.decreaseMasterWidth()

  createControl(keyCombo, $wmcMoveWindowToScratchpad):
    this.moveWindowToScratchpad()

  createControl(keyCombo, $wmcPopScratchpad):
    this.popScratchpad()

  createControl(keyCombo, $wmcRotateclients):
    this.selectedMonitor.rotateClients()

  createControl(keyCombo, $wmcToggleStatusBar):
    this.selectedMonitor.toggleStatusBar()

proc focus*(this: WindowManager, client: Client, warpToClient: bool) =
  for monitor in this.monitors.values():
    for taggedClient in monitor.taggedClients.clients:
      if taggedClient != client:
        this.unfocus(taggedClient)

  this.selectedMonitor.setSelectedClient(client)
  this.selectedMonitor.focusClient(client, warpToClient)
  this.grabButtons(client, true)
  if client.isFloating:
    discard XRaiseWindow(this.display, client.window)

proc unfocus*(this: WindowManager, client: Client) =
  this.grabButtons(client, false)
  discard XSetWindowBorder(
    this.display,
    client.window,
    this.windowSettings.borderColorUnfocused
  )

proc grabButtons*(this: WindowManager, client: Client, focused: bool) =
  ## Grabs key combos defined in the user's config
  updateNumlockMask(this.display)
  let modifiers = [0.cuint, LockMask.cuint, numlockMask, numlockMask or LockMask.cuint]

  discard XUngrabButton(this.display, AnyButton, AnyModifier, client.window)

  if not focused:
    discard XGrabButton(
      this.display,
      AnyButton,
      AnyModifier,
      client.window,
      false,
      MOUSE_MASK,
      GrabModeSync,
      GrabModeSync,
      x.None,
      x.None
    )

  # We only care about left and right clicks
  for button in @[Button1, Button3]:
    for modifier in modifiers:
      discard XGrabButton(
        this.display,
        button,
        this.config.windowSettings.modKey or modifier.int,
        client.window,
        false,
        MOUSE_MASK,
        GrabModeAsync,
        GrabModeSync,
        x.None,
        x.None
      )

proc grabKeys*(this: WindowManager) =
  updateNumlockMask(this.display)
  let modifiers = [0.cuint, LockMask.cuint, numlockMask, numlockMask or LockMask.cuint]
  discard XUngrabKey(this.display, AnyKey, AnyModifier, this.rootWindow)
  for keyCombo in this.config.keyComboTable.keys:
    for modifier in modifiers:
      discard XGrabKey(
        this.display,
        keyCombo.keycode,
        keyCombo.modifiers or modifier,
        this.rootWindow,
        true,
        GrabModeAsync,
        GrabModeAsync
      )

proc errorHandler(display: PDisplay, error: PXErrorEvent): cint{.cdecl.} =
  var errorMessage: string = newString(1024)
  discard XGetErrorText(
    display,
    cint(error.error_code),
    errorMessage.cstring,
    errorMessage.len
  )
  # Reduce string length down to the proper size
  errorMessage.setLen(errorMessage.cstring.len)
  log errorMessage, lvlError

proc destroySelectedWindow*(this: WindowManager) =
  this.selectedMonitor.taggedClients.withSomeCurrClient(client):
    var
      selectedWin = client.window
      event = XEvent()
      numProtocols: int
      exists: bool
      protocols: PAtom

    if XGetWMProtocols(this.display, selectedWin, protocols.addr, cast[Pcint](numProtocols.addr)) != 0:
      let protocolsArr = cast[ptr UncheckedArray[Atom]](protocols)
      while not exists and numProtocols > 0:
        numProtocols.dec
        exists = protocolsArr[numProtocols] == $WMDelete
      discard XFree(protocols)

    if exists:
      event.xclient.theType = ClientMessage
      event.xclient.window = selectedWin
      event.xclient.message_type = $WMProtocols
      event.xclient.format = 32
      event.xclient.data.l[0] = ($WMDelete).cint
      event.xclient.data.l[1] = CurrentTime
      event.xclient.data.l[2] = 0
      event.xclient.data.l[3] = 0
      event.xclient.data.l[4] = 0
      discard XSendEvent(this.display, selectedWin, false, NoEventMask, addr(event))

    if not exists:
      discard XGrabServer(this.display)
      proc dummy(display: PDisplay, e: PXErrorEvent): cint {.cdecl.} = 0.cint
      discard XSetErrorHandler(dummy)
      discard XSetCloseDownMode(this.display, DestroyAll)
      discard XKillClient(this.display, selectedWin)
      discard XSync(this.display, false)
      discard XSetErrorHandler(errorHandler)
      discard XUngrabServer(this.display)

proc onConfigureRequest(this: WindowManager, e: XConfigureRequestEvent) =
  var (client, monitor) = this.windowToClient(e.window)

  if client != nil:

    if this.moveResizingClient == client:
      return

    if (e.value_mask and CWBorderWidth) != 0 and e.border_width > 0:
      client.borderWidth = e.border_width
    elif client.isFloating:
      if (e.value_mask and CWX) != 0:
        client.oldX = client.x
        client.x = monitor.area.x + e.x
      if (e.value_mask and CWY) != 0:
        client.oldY = client.y
        client.y = monitor.area.y + e.y
      if (e.value_mask and CWWidth) != 0:
        client.oldWidth = client.width.uint
        client.width = e.width.uint
      if (e.value_mask and CWHeight) != 0:
        client.oldHeight = client.height.uint
        client.height = e.height.uint

      if not client.isFixedSize:
        if client.x == 0:
          client.x = monitor.area.x + (monitor.area.width.int div 2 - (client.width.int div 2))
        if client.y == 0:
          client.y = monitor.area.y + (monitor.area.height.int div 2 - (client.height.int div 2))

      if (client.x + client.width) > monitor.area.x + monitor.area.width:
        # Center in X direction
        client.x = monitor.area.x + (monitor.area.width.int div 2 - client.totalWidth div 2)
      if (client.y + client.height) > monitor.area.y + monitor.area.height:
        # Center in Y direction
        client.y = monitor.area.y + (monitor.area.height.int div 2 - client.totalHeight div 2)

      if (e.value_mask and (CWX or CWY)) != 0 and (e.value_mask and (CWWidth or CWHeight)) == 0:
        client.configure(this.display)
      if monitor == this.selectedMonitor and monitor.taggedClients.currClientsContains(client):
        discard XMoveResizeWindow(
          this.display,
          e.window,
          client.x,
          client.y,
          client.width.cint,
          client.height.cint
        )
      else:
        client.needsResize = true
    else:
      client.configure(this.display)
  else:
    var changes: XWindowChanges
    changes.x = e.x
    changes.y = e.y
    changes.width = e.width
    changes.height = e.height
    changes.border_width = e.border_width
    changes.sibling = e.above
    changes.stack_mode = e.detail
    discard XConfigureWindow(this.display, e.window, e.value_mask.cuint, changes.addr)

  discard XSync(this.display, false)

proc onConfigureNotify(this: WindowManager, e: XConfigureEvent) =
  if e.window == this.rootWindow:
    log "rootWindow onConfigureNotify"
    let hasRootWindowSizeChanged = e.width != this.rootWindowWidth or e.height != this.rootWindowHeight
    this.rootWindowWidth = e.width
    this.rootWindowHeight = e.height

    let monitorAreas = this.display.getMonitorAreas(this.rootWindow)
    # TODO: Compare existing monitors' areas to new ones.
    # If any have changed, we need to update the positions, sizes, bars, and doLayout.

proc addIconToSystray(this: WindowManager, window: Window) =
  var
    windowAttr: XWindowAttributes
    setWindowAttr: XSetWindowAttributes

  var icon: Icon = newIcon(window)
  this.systray.addIcon(icon)

  discard XGetWindowAttributes(this.display, icon.window, windowAttr.addr)

  icon.width = windowAttr.width
  icon.oldwidth = windowAttr.width
  icon.height = windowAttr.height
  icon.oldHeight = windowAttr.height
  icon.oldBorderWidth = windowAttr.border_width
  icon.borderWidth = 0
  icon.isFloating = true
  icon.hasBeenMapped = true

  this.updateSizeHints(Client(icon), this.systrayMonitor)
  this.updateSystrayIconGeom(icon, windowAttr.width, windowAttr.height)

  discard XAddToSaveSet(this.display, icon.window)
  discard XSelectInput(
    this.display,
    icon.window,
    StructureNotifyMask or PropertyChangeMask or ResizeRedirectMask
  )

  var classHint: XClassHint
  classHint.res_name = "nimdowsystray"
  classHint.res_class = "nimdowsystray"
  discard XSetClassHint(this.display, icon.window, classHint.addr)

  discard XReparentWindow(
    this.display,
    icon.window,
    this.systray.window,
    0,
    0
  )

  # Use parent's background color
  setWindowAttr.background_pixel = this.systrayMonitor.statusBar.bgColor.pixel
  discard XChangeWindowAttributes(this.display, icon.window, CWBackPixel, setWindowAttr.addr)
  discard sendEvent(
    this.display,
    icon.window,
    $Xembed,
    StructureNotifyMask,
    CurrentTime,
    XEMBED_EMBEDDED_NOTIFY,
    0,
    this.systray.window.clong,
    XEMBED_EMBEDDED_VERSION
  )

  discard XSync(this.display, false)

  this.systrayMonitor.statusBar.resizeForSystray(this.systray.getWidth())
  this.updateSystray()
  this.display.setClientState(icon.window, NormalState)

proc onClientMessage(this: WindowManager, e: XClientMessageEvent) =
  if e.window == this.systray.window and e.message_type == $NetSystemTrayOP:
    if e.data.l[1] == SYSTEM_TRAY_REQUEST_DOCK:
      if e.data.l[2] != 0:
        this.addIconToSystray(e.data.l[2])
    return

  var (client, monitor) = this.windowToClient(e.window)
  if client != nil:
    if e.message_type == $NetWMState:
      let fullscreenAtom = $NetWMStateFullScreen
      if e.data.l[1] == fullscreenAtom.clong or
        e.data.l[2] == fullscreenAtom.clong:
        # See the end of this section:
        # https://specifications.freedesktop.org/wm-spec/wm-spec-1.3.html#idm45805407959456
          var shouldFullscreen =
            e.data.l[0] == 1 or
            e.data.l[0] == 2 and not client.isFullscreen
          monitor.setFullscreen(client, shouldFullscreen)
    elif e.message_type == $NetActiveWindow:
      this.selectedMonitor.taggedClients.withSomeCurrClient(currClient):
        if client != currClient and not client.isUrgent:
          client.setUrgent(this.display, true)

proc centerClientIfNeeded(
  this: WindowManager,
  client: var Client,
  monitor: Monitor
) =
  if client.x <= 0 and client.y <= 0:
    # Center the client if its position is top-left or off screen.
    let area = monitor.area
    client.x = (area.x.float + (area.width.float - client.totalWidth.float) / 2).int
    client.y = (area.y.float + (area.height.float - client.totalHeight.float) / 2).int

    if monitor == this.selectedMonitor and
       monitor.taggedClients.currClientsContains(client.window):
      discard XMoveWindow(
        this.display,
        client.window,
        client.x,
        client.y
      )
    else:
      client.needsResize = true

proc updateWindowType(this: WindowManager, client: var Client) =
  let
    stateOpt = this.display.getProperty[:Atom](client.window, $NetWMState)
    windowTypeOpt = this.display.getProperty[:Atom](client.window, $NetWMWindowType)

  let state = if stateOpt.isSome: stateOpt.get else: x.None
  let windowType = if windowTypeOpt.isSome: windowTypeOpt.get else: x.None

  let (_, monitor) = this.windowToClient(client.window)
  if state == $NetWMStateFullScreen:
    if monitor != nil:
      monitor.setFullscreen(client, true)

  if windowType == $NetWMWindowTypeDialog or
     windowType == $NetWMWindowTypeSplash or
     windowType == $NetWMWindowTypeUtility or
     windowType == $NetWMStateModal or
     state == $NetWMStateModal:
    client.isFloating = true
    if monitor != nil:
      this.centerClientIfNeeded(client, monitor)

proc updateSizeHints(this: WindowManager, client: var Client, monitor: Monitor) =
  var sizeHints = XAllocSizeHints()
  var returnMask: int
  if XGetWMNormalHints(this.display, client.window, sizeHints, returnMask.addr) == 0:
    sizeHints.flags = PSize

  if sizeHints.min_width > 0 and sizeHints.min_width == sizeHints.max_width and
     sizeHints.min_height > 0 and sizeHints.min_height == sizeHints.max_height:

    client.isFloating = true
    client.width = max(client.width, sizeHints.min_width.uint)
    client.height = max(client.height, sizeHints.min_height.uint)
    client.needsResize = true

    this.centerClientIfNeeded(client, monitor)

  discard XFree(sizeHints)

proc updateWMHints(this: WindowManager, client: Client) =
  var hints: PXWMHints = XGetWMHints(this.display, client.window)
  if hints == nil:
    return

  let currClient = this.selectedMonitor.taggedClients.currClient
  if currClient != nil and currClient == client and (hints.flags and XUrgencyHint) != 0:
    hints.flags = hints.flags and (not XUrgencyHint)
    discard XSetWMHints(this.display, client.window, hints)
  else:
    # Only case where this should be set directly.
    client.isUrgent = (hints.flags and XUrgencyHint) != 0
    if client.isUrgent:
      discard XSetWindowBorder(
        this.display,
        client.window,
        this.config.windowSettings.borderColorUrgent
      )
      for monitor in this.monitors.values():
        if monitor.taggedClients.contains(client.window):
          monitor.redrawStatusBar()
          break
  discard XFree(hints)

proc getAppRule(this: WindowManager, client: Client): AppRule =
  let classHint = this.display.getWindowClassHint(client.window)
  if classHint == nil:
    return nil

  let title = this.display.getWindowName(client.window)
  for rule in this.config.appRules:
    if rule.matches(title, $classHint.res_name, $classHint.res_class):
      result = rule
      break

  discard XFree(classHint)

proc manage(this: WindowManager, window: Window, windowAttr: XWindowAttributes) =
  var
    client: Client
    monitor = this.selectedMonitor
    appRule: AppRule
    x = windowAttr.x
    y = windowAttr.y
    width = windowAttr.width
    height = windowAttr.height
    borderWidth = windowAttr.borderWidth

  var (c, m) = this.windowToClient(window)
  if c != nil:
    monitor = m
    client = c
  else:
    client = newClient(window)

    # Assign to monitor & tags based on this.config.appRules
    appRule = this.getAppRule(client)
    if appRule != nil:
      # Use appRule tags
      client.tagIDs.clear()
      for tagID in appRule.tagIDs:
        client.tagIDs.incl(tagID)
      # Assign to appRule monitor
      if this.monitors.hasKey(appRule.monitorID):
        monitor = this.monitors[appRule.monitorID]

      # Set state based on app rule
      if appRule.state == wsFloating:
        client.isFloating = true

        # AppRule x and y are default -1 when not set.
        if appRule.x >= 0:
          x = appRule.x
        if appRule.y >= 0:
          y = appRule.y

        # AppRule width and height are default 0 when not set.
        if appRule.width > 0:
          width = appRule.width
        if appRule.height > 0:
          height = appRule.height

    let appRuleDoesNotHaveValidTags = appRule == nil or appRule.tagIDs.len == 0
    monitor.addClient(client, appRuleDoesNotHaveValidTags)
    client.x = monitor.area.x + max(0, x)
    client.oldX = client.x
    client.y = monitor.area.y + max(0, y)
    client.oldY = client.y
    client.width = width
    client.oldWidth = client.width
    client.height = height
    client.oldHeight = client.height
    client.borderWidth = this.config.windowSettings.borderWidth
    client.oldBorderWidth = borderWidth

  if client.x - monitor.area.x <= 0 or
     (client.x + client.totalWidth) > monitor.area.x + monitor.area.width:
    client.x = (
      monitor.area.x.float +
      (monitor.area.width.float - client.totalWidth.float) / 2
    ).int

  if client.y - monitor.area.y <= monitor.statusBar.area.height or
     (client.y + client.totalHeight) > monitor.area.y + monitor.area.height:
    client.y = (
      monitor.area.y.float +
      (monitor.area.height.float - client.totalHeight.float) / 2
    ).int

  # If no tags are selected, add the client to the first tag.
  if client.tagIDs.len == 0:
    client.tagIDs.incl(monitor.taggedClients.tags[0].id)

  discard XSetWindowBorder(
    this.display,
    window,
    this.windowSettings.borderColorUnfocused
  )

  discard XSelectInput(
    this.display,
    window,
    StructureNotifyMask or
    PropertyChangeMask or
    ResizeRedirectMask or
    EnterWindowMask or
    FocusChangeMask
  )

  this.grabButtons(client, false)

  this.updateWindowType(client)
  this.updateSizeHints(client, monitor)
  this.updateWMHints(client)

  monitor.addWindowToClientListProperty(window)

  discard XMoveResizeWindow(
    this.display,
    window,
    client.x + 2 * this.rootWindowWidth,
    client.y,
    client.width.cuint,
    client.height.cuint
  )

  client.needsResize = false

  this.display.setClientState(client.window, NormalState)
  if monitor == this.selectedMonitor and monitor.taggedClients.currClientsContains(window):
    client.adjustToState(this.display)

  if appRule != nil and appRule.state == wsFullscreen:
    if monitor.taggedClients.currClientsContains(window):
      monitor.setFullscreen(client, true)
    else:
      client.needsFullscreen = true
  elif
    not client.isFixedSize and
    not client.isFloating and
    monitor.taggedClients.currClientsContains(window):
      monitor.doLayout(false, not client.isFloating)

  discard XMapWindow(this.display, window)
  client.hasBeenMapped = true

  if monitor == this.selectedMonitor and monitor.taggedClients.currClientsContains(window):
    let shouldWarp =
      (
        not client.isFloating or
        client.isFullscreen or
        monitor.taggedClients.currClientsLen == 1
      )

    this.focus(client, shouldWarp)
    monitor.focusClient(client, shouldWarp)

proc onMapRequest(this: WindowManager, e: XMapRequestEvent) =
  var windowAttr: XWindowAttributes

  let icon = this.systray.windowToIcon(e.window)
  if icon != nil:
    discard this.display.sendEvent(
      icon.window,
      $Xembed,
      StructureNotifyMask,
      CurrentTime,
      XEMBED_WINDOW_ACTIVATE,
      0,
      this.systray.window.clong,
      XEMBED_EMBEDDED_VERSION
    )
    this.systrayMonitor.statusBar.resizeForSystray(this.systray.getWidth())
    this.updateSystray()

  if XGetWindowAttributes(this.display, e.window, windowAttr.addr) == 0:
    return
  if windowAttr.override_redirect:
    return

  let (_, existingClient) = this.windowToClient(e.window)
  if existingClient != nil:
    return

  this.manage(e.window, windowAttr)

proc unmanage(this: WindowManager, window: Window, destroyed: bool) =
  let (client, monitor) = this.windowToClient(window)
  if client != nil:
    discard monitor.removeWindow(window)
    if not destroyed:
      var winChanges: XWindowChanges
      winChanges.border_width = client.oldBorderWidth.cint
      discard XGrabServer(this.display)
      proc dummy(display: PDisplay, e: PXErrorEvent): cint {.cdecl.} = 0.cint
      discard XSetErrorHandler(dummy)
      discard XConfigureWindow(this.display, window, CWBorderWidth, winChanges.addr)
      discard XUngrabButton(this.display, AnyButton, AnyModifier, window)
      this.display.setClientState(client.window, WithdrawnState)
      discard XSync(this.display, false)
      discard XSetErrorHandler(errorHandler)
      discard XUngrabServer(this.display)

    monitor.doLayout(false)
    monitor.updateClientList()
    monitor.statusBar.redraw()

    if monitor == this.selectedMonitor:
      this.selectedMonitor.taggedClients.withSomeCurrClient(currClient):
        this.focus(currClient, false)

proc removeIconFromSystray(this: WindowManager, window: Window) =
  let icon = this.systray.windowToIcon(window)
  if icon != nil:
    this.systray.removeIcon(icon)
    this.systrayMonitor.statusBar.resizeForSystray(this.systray.getWidth())
    this.updateSystray()

proc onDestroyNotify(this: WindowManager, e: XDestroyWindowEvent) =
  let (client, _) = this.windowToClient(e.window)
  if client != nil:
    this.unmanage(e.window, true)
  else:
    this.removeIconFromSystray(e.window)

proc onUnmapNotify(this: WindowManager, e: XUnmapEvent) =
  let (client, _) = this.windowToClient(e.window)
  if client != nil:
    if e.send_event:
      this.display.setClientState(client.window, WithdrawnState)
    else:
      this.unmanage(client.window, false)
  else:
    this.removeIconFromSystray(e.window)

proc onMappingNotify(this: WindowManager, e: XMappingEvent) =
  var pevent: PXMappingEvent = e.unsafeaddr
  discard XRefreshKeyboardMapping(pevent)

  if e.request == MappingKeyboard:
    this.grabkeys()

proc selectCorrectMonitor(this: WindowManager, x, y: int) =
  for monitor in this.monitors.values():
    if not monitor.area.contains(x, y):
      continue

    if monitor == this.selectedMonitor:
      # Coords are in the current monitor - exit early.
      break

    var previousMonitor = this.selectedMonitor
    this.setSelectedMonitor(monitor)
    # Set old monitor's focused window's border to the unfocused color
    previousMonitor.taggedClients.withSomeCurrClient(client):
      discard XSetWindowBorder(
        this.display,
        client.window,
        this.windowSettings.borderColorUnfocused
      )
    # Focus the new monitor's current client
    let currClient = this.selectedMonitor.taggedClients.currClient
    if currClient != nil:
      this.focus(currClient, false)
    else:
      discard XSetInputFocus(this.display, this.rootWindow, RevertToPointerRoot, CurrentTime)
    break

proc updateSystray(this: WindowManager) =
  var
    setWindowAttr: XSetWindowAttributes
    backgroundColor = this.systrayMonitor.statusBar.bgColor
    x = this.systrayMonitor.area.x + this.systrayMonitor.area.width.int

  let
    backgroundPixel = backgroundColor.pixel
    barHeight = this.selectedMonitorConfig.barSettings.height

  if this.systray == nil:
    this.systray = Systray()

    this.systray.window = XCreateSimpleWindow(
      this.display,
      this.rootWindow,
      x,
      this.systrayMonitor.statusBar.area.y,
      1,
      barHeight,
      0,
      0,
      # TODO: If this gets called when reloading config and changing color, this should work?
      backgroundPixel
    )

    setWindowAttr.event_mask = ButtonPressMask or ExposureMask
    setWindowAttr.override_redirect = true
    setWindowAttr.background_pixel = backgroundPixel

    discard XSelectInput(this.display, this.systray.window, SubstructureNotifyMask)
    discard XChangeProperty(
      this.display,
      this.systray.window,
      $NetSystemTrayOrientation,
      XA_CARDINAL,
      32,
      PropModeReplace,
      cast[Pcuchar](($NetSystemTrayOrientation).addr),
      1
    )
    discard XChangeWindowAttributes(
      this.display,
      this.systray.window,
      CWEventMask or CWOverrideRedirect or CWBackPixel,
      setWindowAttr.addr
    )
    discard XMapRaised(this.display, this.systray.window)
    discard XSetSelectionOwner(this.display, $NetSystemTray, this.systray.window, CurrentTime)

    if XGetSelectionOwner(this.display, $NetSystemTray) == this.systray.window:
      discard this.display.sendEvent(
        this.rootWindow,
        $Manager,
        StructureNotifyMask,
        CurrentTime,
        ($NetSystemTray).clong,
        this.systray.window.clong,
        0,
        0
      )
      discard XSync(this.display, false)
    else:
      log("Unable to obtain systray", lvlError)
      this.systray = nil
      return

    this.systrayMonitor.systray = this.systray

  let barArea = this.systrayMonitor.statusBar.area

  var systrayWidth: int
  for icon in this.systray.icons:
    setWindowAttr.background_pixel = backgroundPixel
    discard XChangeWindowAttributes(this.display, icon.window, CWBackPixel, setWindowAttr.addr)
    discard XMapRaised(this.display, icon.window)
    systrayWidth += systrayIconSpacing
    icon.x = systrayWidth

    let centerY = (barArea.height.float / 2 - icon.height.float / 2).int

    discard XMoveResizeWindow(
      this.display,
      icon.window,
      icon.x,
      centerY,
      icon.width,
      icon.height
    )
    systrayWidth += icon.width.int

  systrayWidth = max(1, systrayWidth + systrayIconSpacing)

  var winChanges: XWindowChanges

  x -= systrayWidth

  discard XMoveResizeWindow(
    this.display,
    this.systray.window,
    x,
    barArea.y,
    systrayWidth,
    barHeight
  )

  winChanges.x = x
  winChanges.y = barArea.y
  winChanges.width = systrayWidth
  winChanges.height = barArea.height.cint
  winChanges.stack_mode = Above
  winChanges.sibling = this.systrayMonitor.statusBar.barWindow

  discard XConfigureWindow(
    this.display,
    this.systray.window,
    CWX or CWY or CWWidth or CWHeight or CWSibling or CWStackMode,
    winChanges.addr
  )

  discard XMapWindow(this.display, this.systray.window)
  discard XMapSubwindows(this.display, this.systray.window)

  discard XSync(this.display, false)

proc updateSystrayIconGeom(this: WindowManager, icon: Icon, width, height: int) =
  if icon == nil:
    return

  let barHeight = this.selectedMonitorConfig.barSettings.height
  icon.height = barHeight
  if width == height:
    icon.width = barHeight
  elif height == barHeight:
    icon.width = width
  else:
    icon.width = int(barHeight.float * (width / height))

proc updateSystrayIconState(this: WindowManager, icon: Icon, e: XPropertyEvent) =
  if icon == nil or e.atom != $XembedInfo:
    return

  let
    flagsOpt = this.display.getProperty[:Atom](icon.window, $XembedInfo)
    flags: clong = if flagsOpt.isSome: flagsOpt.get.clong else: 0

  if flags == 0:
    return

  var iconActiveState: int
  if (flags and XEMBED_MAPPED) != 0 and not icon.hasBeenMapped:
    # Requesting to be mapped
    icon.hasBeenMapped = true
    iconActiveState = XEMBED_WINDOW_ACTIVATE
    discard XMapRaised(this.display, icon.window)
    this.display.setClientState(icon.window, NormalState)
  elif (flags and XEMBED_MAPPED) == 0 and icon.hasBeenMapped:
    # Requesting to be upmapped
    icon.hasBeenMapped = false
    iconActiveState = XEMBED_WINDOW_DEACTIVATE
    discard XUnmapWindow(this.display, icon.window)
    this.display.setClientState(icon.window, WithdrawnState)
  else:
    return

  discard this.display.sendEvent(
    icon.window,
    $Xembed,
    StructureNotifyMask,
    CurrentTime,
    iconActiveState,
    0,
    this.systray.window.clong,
    XEMBED_EMBEDDED_VERSION
  )

proc onResizeRequest(this: WindowManager, e: XResizeRequestEvent) =
  let icon = this.systray.windowToIcon(e.window)
  if icon == nil:
    return

  this.updateSystrayIconGeom(icon, e.width, e.height)
  let monitor = this.monitors[systrayMonitorID]
  monitor.statusBar.resizeForSystray(this.systray.getWidth())
  this.updateSystray()

proc onMotionNotify(this: WindowManager, e: XMotionEvent) =
  # If moving/resizing a client, we delay selecting the new monitor.
  if this.mouseAction == MouseAction.Normal:
    this.selectCorrectMonitor(e.x_root, e.y_root)
  this.handleMouseMotion(e)

proc onEnterNotify(this: WindowManager, e: XCrossingEvent) =
  if this.mouseAction != MouseAction.Normal or e.window == this.rootWindow:
    return

  this.selectCorrectMonitor(e.x_root, e.y_root)
  if this.selectedMonitor.taggedClients.currClientsContains(e.window):
    discard XSetInputFocus(this.display, e.window, RevertToPointerRoot, CurrentTime)

proc onFocusIn(this: WindowManager, e: XFocusInEvent) =
  if this.mouseAction != Normal or e.detail == NotifyPointer or e.window == this.rootWindow:
    if this.selectedMonitor.taggedClients.currClient == nil:
      # Clear the window title (no windows are focused)
      this.selectedMonitor.statusBar.setActiveWindowTitle("")
    return

  # Do not allow focus stealing if the client is not visible on any monitor.
  let (client, monitor) = this.windowToClient(e.window)
  if monitor == nil or client == nil or not monitor.taggedClients.currClientsContains(client):
    this.selectedMonitor.taggedClients.withSomeCurrClient(currClient):
      this.focus(currClient, true)
    return

  let previousSelectedClient = this.selectedMonitor.taggedClients.currClient
  let previousSelectedClientWasFloating =
    (previousSelectedClient != nil and previousSelectedClient.isFloating)

  if monitor != this.selectedMonitor:
    this.setSelectedMonitor(monitor)

  if previousSelectedClient != nil:
    this.unfocus(previousSelectedClient)

  this.selectedMonitor.setActiveWindowProperty(client.window)
  this.selectedMonitor.setSelectedClient(client)
  this.grabButtons(client, true)
  # Don't raise the newly selected floating window if the last was also floating.
  if not previousSelectedClientWasFloating and client.isFloating:
    discard XRaiseWindow(this.display, client.window)

proc setStatus(this: WindowManager, monitorIndex: int, status: string) =
  let monitorID = monitorIndex + 1
  if not this.monitors.hasKey(monitorID):
    raise newException(ValueError, "monitor index " & $monitorIndex & " is out of range")
  this.monitors[monitorID].statusBar.setStatus(status)

proc setStatusForAllMonitors(this: WindowManager, status: string) =
  for monitor in this.monitors.values():
    monitor.statusBar.setStatus(status)

proc renderStatus(this: WindowManager) =
  ## Renders the status on all status bars.
  var name: cstring
  if XFetchName(this.display, this.rootWindow, name.addr) == 0:
    return

  let statuses = ($name).split(STATUS_MONITOR_PREFIX)
  if statuses.len == 1:
    this.setStatusForAllMonitors(statuses[0])
  else:
    try:
      for rawStatus in statuses[1 .. statuses.high]:
        var
          monitorIndexAsStr = rawStatus[0..skipUntil(rawStatus, Whitespace) - 1]
          monitorIndex = parseInt(monitorIndexAsStr)

        var status = rawStatus
        status.removePrefix(monitorIndexAsStr)
        this.setStatus(monitorIndex, status)
    except ValueError:
      let msg = getCurrentExceptionMsg()
      this.setStatusForAllMonitors(msg)
      log(msg, lvlError)

proc windowToMonitor(this: WindowManager, window: Window): Monitor =
  for monitor in this.monitors.values():
    if window == monitor.statusBar.barWindow:
      return monitor
    if monitor.taggedClients.contains(window):
      return monitor

proc windowToClient(
  this: WindowManager,
  window: Window
): tuple[client: Client, monitor: Monitor] =
  ## Finds a client based on its window.
  ## Both the returned values will either be nil, or valid.
  var client: Client
  for monitor in this.monitors.values():
    client = monitor.taggedClients.findByWindow(window)
    if client != nil:
      return (client, monitor)

proc onPropertyNotify(this: WindowManager, e: XPropertyEvent) =
  let icon = this.systray.windowToIcon(e.window)
  if icon != nil:
    if e.atom == XA_WM_NORMAL_HINTS:
      this.updateSystrayIconGeom(icon, icon.width.int, icon.height.int)
    else:
      this.updateSystrayIconState(icon, e)
    this.systrayMonitor.statusBar.resizeForSystray(this.systray.getWidth())
    this.updateSystray()

  if e.window == this.rootWindow and e.atom == XA_WM_NAME:
    this.renderStatus()
  elif e.state == PropertyDelete:
    return
  else:
    var (client, monitor) = this.windowToClient(e.window)
    if client == nil:
      return

    case e.atom:
      of XA_WM_TRANSIENT_FOR:
        var transientWin: Window
        if not client.isFloating and
          XGetTransientForHint(this.display, client.window, transientWin.addr) != 0:
          let c = this.windowToClient(transientWin)
          client.isFloating = c.client != nil
          if client.isFloating:
            monitor.doLayout()
      of XA_WM_NORMAL_HINTS, XA_WM_SIZE_HINTS:
        this.updateSizeHints(client, monitor)
      of XA_WM_HINTS:
        this.updateWMHints(client)
        for monitor in this.monitors.values():
          monitor.redrawStatusBar()
      else:
        discard

    if e.atom == XA_WM_NAME or e.atom == $NetWMName:
      let currClient = monitor.taggedClients.currClient
      if currClient != nil:
        if currClient == client:
          let name = this.display.getWindowName(client.window)
          monitor.statusBar.setActiveWindowTitle(name)

    if e.atom == $NetWMWindowType:
      this.updateWindowType(client)

    if client.needsResize and
       monitor == this.selectedMonitor and
       monitor.taggedClients.currClientsContains(client):
      client.show(this.display)
      monitor.doLayout(false)

proc onExposeNotify(this: WindowManager, e: XExposeEvent) =
  if e.count == 0:
    let monitor = this.windowToMonitor(e.window)
    if monitor != nil:
      monitor.redrawStatusBar()
      if monitor == this.selectedMonitor:
        this.updateSystray()

proc selectClientForMoveResize(this: WindowManager, e: XButtonEvent) =
  let client = this.selectedMonitor.taggedClients.currClient
  if client == nil:
    return
  this.moveResizingClient = client
  this.lastMousePress = (e.xRoot.int, e.yRoot.int)
  this.lastMoveResizeClientState = client.area

proc findClient(this: WindowManager, e: XButtonEvent): Client =
  for monitor in this.monitors.values():
    let client = monitor.taggedClients.findByWindow(e.window)
    if client != nil:
      return client

proc handleButtonPressed(this: WindowManager, e: XButtonEvent) =
  if e.window == this.systray.window:
    # Clicked systray window, don't do anything.
    return

  for monitor in this.monitors.values:
    if e.window == monitor.statusBar.barWindow:
      let clickedInfo = getClickedRegion(monitor.statusBar, e)

      if clickedInfo.regionID == -1:
        # Nothing was clicked
        return

      if clickedInfo.regionID in (0 ..< monitor.statusBar.tagSettings.len):
        case e.button:
          of Button4:
            let tag =
              if this.config.reverseTagScrolling:
                this.findRightTag()
              else:
                this.findLeftTag()

            if tag != nil:
              this.goToTag(tag.id, false)

          of Button5:
            let tag =
              if this.config.reverseTagScrolling:
                this.findLeftTag()
              else:
                this.findRightTag()

            if tag != nil:
              this.goToTag(tag.id, false)
          else:
            this.goToTag(clickedInfo.regionID + 1, false)
        return

      let regionID =
        if clickedInfo.regionID == monitor.statusBar.tagSettings.len:
          0
        else:
          clickedInfo.regionID - monitor.statusBar.tagSettings.len

      if this.config.regionClickActionTable.hasKey(regionID):
        this.config.regionClickActionTable[regionID](
          clickedInfo.index,
          clickedInfo.width,
          clickedInfo.regionCord,
          clickedInfo.clickCord
        )
      return

  # Need to not change mouse state if e.state is not the mod key.
  case e.button:
    of Button1:
      if cleanMask(int e.state) == this.config.windowSettings.modKey:
        this.mouseAction = MouseAction.Moving
        this.selectClientForMoveResize(e)
    of Button3:
      if cleanMask(int e.state) == this.config.windowSettings.modKey:
        this.mouseAction = MouseAction.Resizing
        this.selectClientForMoveResize(e)
    else:
      this.mouseAction = MouseAction.Normal

  let client = this.findClient(e)
  if client != nil:
    this.focus(client, false)
    discard XAllowEvents(this.display, ReplayPointer, CurrentTime)

proc handleButtonReleased(this: WindowManager, e: XButtonEvent) =
  this.mouseAction = MouseAction.Normal

  if this.moveResizingClient == nil:
    return

  var client = this.moveResizingClient
  # Unset the client being moved/resized
  this.moveResizingClient = nil

  # Check if we are on a new monitor.
  let
    centerX = client.x + client.width.int div 2
    centerY = client.y + client.height.int div 2

  let (_, nextMonitor) = this.monitors.find(centerX, centerY)

  if nextMonitor == nil or nextMonitor == this.selectedMonitor:
    return

  let prevMonitor = this.selectedMonitor
  # Remove client from current monitor/tag
  if not prevMonitor.removeWindow(client.window):
    log "Failed to remove window " & $client.window & " from monitor"
    return

  # NOTE: `nextMonitor` is set as the selectedMonitor via `onMotionNotify`
  nextMonitor.addClient(client)

proc handleMouseMotion(this: WindowManager, e: XMotionEvent) =
  if this.mouseAction == Normal or this.moveResizingClient == nil:
    return

  var client = this.moveResizingClient
  if client.isFullscreen:
    return

  # Prevent trying to process events too quickly (causes major lag).
  if e.time - this.lastMoveResizeTime < minimumUpdateInterval:
    return

  # Track the last time we moved or resized a window.
  this.lastMoveResizeTime = e.time

  if not client.isFloating:
    this.selectedMonitor.setFloating(client, true)

  let
    deltaX = e.xRoot - this.lastMousePress.x
    deltaY = e.yRoot - this.lastMousePress.y

  if this.mouseAction == Moving:
    client.setLocation(
      this.display,
      this.lastMoveResizeClientState.x + deltaX,
      this.lastMoveResizeClientState.y + deltaY
    )
  elif this.mouseAction == Resizing:
    client.resize(
      this.display,
      this.lastMoveResizeClientState.x,
      this.lastMoveResizeClientState.y,
      max(1, this.lastMoveResizeClientState.width.int + deltaX),
      max(1, this.lastMoveResizeClientState.height.int + deltaY)
    )

