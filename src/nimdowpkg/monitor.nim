import
  x11 / [x, xlib, xinerama, xatom],
  sugar,
  tables,
  sets,
  strutils,
  options,
  xatoms,
  tag,
  client,
  area,
  strut,
  layouts/layout,
  layouts/masterstacklayout,
  keys/keyutils,
  config/configloader,
  statusbar,
  utils/optionutils

converter intToCint(x: int): cint = x.cint
converter intToCUint(x: int): cuint = x.cuint
converter cintToCUint(x: cint): cuint = x.cuint
converter intToCUchar(x: int): cuchar = x.cuchar
converter clongToCUlong(x: clong): culong = x.culong
converter toXBool(x: bool): XBool = x.XBool

const
  tagCount = 9
  masterSlots = 1

type
  Monitor* = ref object of RootObj
    display: PDisplay
    rootWindow: Window
    statusBar*: StatusBar
    area*: Area
    config: WindowSettings
    taggedClients*: OrderedTableRef[Tag, seq[Client]]
    selectedTag*: Tag
    previousTag*: Tag
    layoutOffset: LayoutOffset

proc doLayout*(this: Monitor, warpToClient: bool = true)
proc restack*(this: Monitor)
proc setSelectedClient*(this: Monitor, client: Client)
proc updateCurrentDesktopProperty(this: Monitor)

proc newMonitor*(display: PDisplay, rootWindow: Window, area: Area, currentConfig: Config): Monitor =
  result = Monitor()
  result.display = display
  result.rootWindow = rootWindow
  result.area = area
  let barArea: Area = (area.x, 0, area.width, currentConfig.barSettings.height)
  result.config = currentConfig.windowSettings
  result.layoutOffset = (barArea.height, 0.uint, 0.uint, 0.uint)

  result.taggedClients = newOrderedTable[Tag, seq[Client]]()
  for i in 0..<tagCount:
    let tag: Tag = newTag(
      id = i,
      layout = newMasterStackLayout(
        monitorArea = area,
        gapSize = currentConfig.windowSettings.gapSize,
        borderWidth = currentConfig.windowSettings.borderWidth,
        masterSlots = masterSlots
      )
    )
    result.taggedClients[tag] = @[]

  var i = 0
  # View first tag by default
  # Second tag is the `previousTag` by default.
  for tag in result.taggedClients.keys():
    if i == 0:
      result.selectedTag = tag
    elif i == 1:
      result.previousTag = tag
    else:
      break
    i.inc

  result.updateCurrentDesktopProperty()
  result.statusBar =
    display.newStatusBar(
      rootWindow,
      barArea,
      result.taggedClients,
      currentConfig.barSettings
    )

proc setConfig*(this: Monitor, config: Config) =
  this.config = config.windowSettings
  for tag in this.taggedClients.keys():
    tag.layout.gapSize = this.config.gapSize
    tag.layout.borderWidth = this.config.borderWidth
  this.doLayout()
  this.statusBar.setConfig(config.barSettings)

template currTagClients*(this: Monitor): untyped =
  ## Grabs the windows on the current tag.
  ## This is used like an alias, e.g.:
  ## `let clients = this.taggedClients[this.selectedTags]`
  ## `clients` would be a copy of the collection.
  this.taggedClients[this.selectedTag]

template currClient*(this: Monitor): Option[Client] =
  this.selectedTag.selectedClient

template withSomeCurrClient*(this: Monitor, client, body: untyped) =
  ## Executes `body` if `this.currClient.isSome == true`
  ## with the extracted Client value.
  if this.currClient.isSome:
    var client: Client = this.currClient.get
    body

proc redrawStatusBar*(this: Monitor) =
  this.statusBar.redraw()

proc getMonitorAreas*(display: PDisplay, rootWindow: Window): seq[Area] =
  var number: cint
  var screenInfo =
    cast[ptr UncheckedArray[XineramaScreenInfo]]
      (XineramaQueryScreens(display, number.addr))

  for i in countup(0, number - 1):
    result.add((
      x: screenInfo[i].x_org.int,
      y: screenInfo[i].y_org.int,
      width: screenInfo[i].width.uint,
      height: screenInfo[i].height.uint
    ))

proc calculateStrutArea*(strut: Strut, displayWidth, displayHeight: int): Area =
  if strut.left != 0:
    return (
      0,
      strut.leftStartY.int,
      strut.left,
      strut.leftEndY - strut.leftStartY + 1
    )

  elif strut.right != 0:
    return (
      displayWidth - strut.right.int,
      strut.rightStartY.int,
      strut.right,
      strut.rightEndY - strut.rightStartY + 1
    )

  elif strut.top != 0:
    return (
      strut.topStartX.int,
      0,
      strut.topEndX - strut.topStartX + 1,
      strut.top
    )

  elif strut.bottom != 0:
    return (
      strut.bottomStartX.int,
      displayHeight - strut.bottom.int,
      strut.bottomEndX - strut.bottomStartX + 1,
      strut.bottom
    )

  else:
    echo "ERROR: No invalid strut!"
  return (0, 0, 0.uint, 0.uint)

proc find*(this: Monitor, window: Window): Option[Client] =
  ## Finds a client based on its window property.
  for tag, clients in this.taggedClients.pairs:
    let index = clients.find(window)
    if index >= 0:
      return clients[index].option
  return none(Client)

proc updateCurrentDesktopProperty(this: Monitor) =
  var data: array[1, clong] = [this.selectedTag.id]
  discard XChangeProperty(
    this.display,
    this.rootWindow,
    $NetCurrentDesktop,
    XA_CARDINAL,
    32,
    PropModeReplace,
    cast[Pcuchar](data[0].addr),
    1
  )

proc keycodeToTag*(this: Monitor, keycode: int): Tag =
  try:
    let tagNumber = parseInt(keycode.toString(this.display))
    if tagNumber < 0:
      raise newException(Exception, "Tag number cannot be negative")

    var i = tagNumber
    for tag in this.taggedClients.keys():
      i -= 1
      if i == 0:
        return tag
  except:
    echo "Invalid tag number from config:"
    echo getCurrentExceptionMsg()

proc focusClient*(this: Monitor, client: Client, warpToClient: bool) =
  this.setSelectedClient(client)

  discard XSetInputFocus(
    this.display,
    client.window,
    RevertToPointerRoot,
    CurrentTime
  )

  client.takeFocus(this.display)

  if warpToClient:
    this.display.warpTo(client)

proc focusRootWindow(this: Monitor) =
  discard XSetInputFocus(
    this.display,
    this.rootWindow,
    RevertToPointerRoot,
    CurrentTime
  )

proc ensureWindowFocus*(this: Monitor) =
  ## Ensures a window is selected on the current tag.
  if this.currTagClients.len == 0:
    this.focusRootWindow()
    this.statusBar.setSelectedClient(nil)
  else:
    if this.currClient.isSome:
      this.focusClient(this.currClient.get, true)
    elif this.selectedTag.previouslySelectedClient.isSome:
      this.focusClient(this.selectedTag.previouslySelectedClient.get, true)
    else:
      # Find the first normal client
      let clientIndex = this.currTagClients.findNextNormal(-1)
      if clientIndex >= 0:
        let client = this.currTagClients[clientIndex]
        this.focusClient(client, true)
      else:
        this.focusRootWindow()
        this.statusBar.setSelectedClient(nil)
        this.statusBar.setActiveWindowTitle("")

proc addWindowToClientListProperty*(this: Monitor, window: Window) =
  ## Adds the window to _NET_CLIENT_LIST
  discard XChangeProperty(
    this.display,
    this.rootWindow,
    $NetClientList,
    XA_WINDOW,
    32,
    PropModeAppend,
    cast[Pcuchar](window.unsafeAddr),
    1
  )

proc updateClientList*(this: Monitor) =
  discard XDeleteProperty(this.display, this.rootWindow, $NetClientList)
  for clients in this.taggedClients.values:
    for client in clients:
      this.addWindowToClientListProperty(client.window)

proc setActiveWindowProperty*(this: Monitor, window: Window) =
  discard XChangeProperty(
    this.display,
    this.rootWindow,
    $NetActiveWindow,
    XA_WINDOW,
    32,
    PropModeReplace,
    cast[Pcuchar](window.unsafeAddr),
    1
  )

proc deleteActiveWindowProperty(this: Monitor) =
  discard XDeleteProperty(this.display, this.rootWindow, $NetActiveWindow)

proc doLayout*(this: Monitor, warpToClient: bool = true) =
  ## Revalidates the current layout of the viewed tag(s).
  this.selectedTag.layout.arrange(
    this.display,
    this.currTagClients,
    this.layoutOffset
  )
  this.restack()
  this.withSomeCurrClient(client):
    if warpToClient:
      this.display.warpTo(client)

proc restack*(this: Monitor) =
  this.withSomeCurrClient(client):
    if client.isFloating:
      discard XRaiseWindow(this.display, client.window)

    var winChanges: XWindowChanges
    winChanges.stack_mode = Below
    winChanges.sibling = this.statusBar.barWindow
    for c in this.currTagClients:
      if not c.isFloating:
        discard XConfigureWindow(
          this.display,
          c.window,
          CWSibling or CWStackMode,
          winChanges.addr
        )
        winChanges.sibling = c.window

    discard XSync(this.display, false)
    var event: XEvent
    while XCheckMaskEvent(this.display, EnterWindowMask, event.addr) != 0:
      discard

proc removeWindowFromTag(this: Monitor, tag: Tag, clientIndex: int) =
  let client = this.taggedClients[tag][clientIndex]
  this.taggedClients[tag].delete(clientIndex)
  tag.clearSelectedClient(client)
  if tag.selectedClient.isNone:
    if this.taggedClients[tag].len > 0:
      # Find and assign the first normal client as "previouslySelectedClient"
      let nextNormalIndex = this.taggedClients[tag].findNextNormal(-1)
      if nextNormalIndex >= 0:
        tag.previouslySelectedClient = this.taggedClients[tag][nextNormalIndex].option
        tag.selectedClient = tag.previouslySelectedClient
    else:
      tag.setSelectedClient(nil)
      this.statusBar.setSelectedClient(nil, false)
      this.statusBar.setActiveWindowTitle("")

proc removeWindowFromTagTable*(this: Monitor, window: Window): bool =
  ## Removes a window from the tag table on this monitor.
  ## Returns if the window was removed from the table.
  result = false
  for tag, clients in this.taggedClients.pairs:
    let clientIndex = clients.find(window)
    if clientIndex >= 0:
      this.removeWindowFromTag(tag, clientIndex)
      result = true

  if this.currTagClients.len > 0:
    let opt = this.selectedTag.selectedClient
    withSome(opt, client):
      this.setSelectedClient(client)
      let opt = this.display.getWindowName(client.window)
      withSome(opt, title):
        this.statusBar.setActiveWindowTitle(title)

proc removeWindow*(this: Monitor, window: Window): bool =
  ## Returns if the window was removed.
  ## After a window is removed, you should typically call
  ## doLayout and ensureWindowFocus (unless you have a specific use case).
  result = this.removeWindowFromTagTable(window)
  this.deleteActiveWindowProperty()
  this.updateClientList()

proc updateWindowTagAtom*(this: Monitor, window: Window, tagID: int) =
  let data: clong = tagID.clong
  discard XChangeProperty(
    this.display,
    window,
    $NetWMDesktop,
    XA_CARDINAL,
    32,
    PropModeReplace,
    cast[Pcuchar](data.unsafeAddr),
    1
  )

proc setSelectedClient*(this: Monitor, client: Client) =
  this.selectedTag.setSelectedClient(client)
  this.statusBar.setSelectedClient(client)

proc moveClientToTag*(this: Monitor, client: Client, destinationTag: Tag) =
  for tag, clients in this.taggedClients.mpairs:
    # This assumes the client is being moved from the current tag to another tag.
    if tag == destinationTag:
      if not clients.contains(client):
        clients.add(client)
        this.updateWindowTagAtom(client.window, destinationTag.id)
        tag.setSelectedClient(client)
        client.hide(this.display)
    else:
      let clientIndex = clients.find(client)
      if clientIndex < 0:
        continue
      this.removeWindowFromTag(tag, clientIndex)
      tag.clearSelectedClient(client)
      if tag == this.selectedTag:
        this.doLayout()
        this.ensureWindowFocus()

  if this.currTagClients.len == 0:
    this.deleteActiveWindowProperty()
    this.statusBar.setActiveWindowTitle("", false)
  this.redrawStatusBar()

proc moveSelectedWindowToTag*(this: Monitor, tag: Tag) =
  withSome(this.currClient, client):
    this.moveClientToTag(client, tag)

proc viewTag*(this: Monitor, tag: Tag) =
  ## Views a single tag.
  if tag == this.selectedTag:
    return

  # TODO: See issue #31
  # Wish we could use OrderedSets,
  # but we cannot easily get by index
  # or even use a `next` proc.
  # Perhaps we should make our own class.
  let setCurrent = toHashSet(this.currTagClients)
  let setNext = toHashSet(this.taggedClients[tag])

  # Windows not on the current tag need to be hidden or unmapped.
  for client in (setCurrent - setNext).items:
    client.hide(this.display)

  this.selectedTag = tag
  this.statusBar.setSelectedTag(this.selectedTag.id, false)
  this.doLayout()

  for client in (setNext - setCurrent).items:
    client.show(this.display)
    # Ensure correct border color is set for each window
    let color =
      if this.selectedTag.isSelectedClient(client):
        this.config.borderColorFocused
      else:
        this.config.borderColorUnfocused
    discard XSetWindowBorder(this.display, client.window, color)

  discard XSync(this.display, false)

  if this.currClient.isSome:
    this.focusClient(this.currClient.get, true)
  else:
    this.deleteActiveWindowProperty()
    this.statusBar.setActiveWindowTitle("", false)
    this.statusBar.setSelectedClient(nil, false)

  this.updateCurrentDesktopProperty()
  this.statusBar.redraw()

proc findSelectedAndNextNormalClientIndexes(
  this: Monitor,
  findNormalClient: proc(clients: openArray[Client], i: int): int
): tuple[selectedIndex, nextIndex: int] =
  ## Finds the index of the currently selected client in currTagClients,
  ## and the index result of findNormalClient.
  ## Either value can be -1 if not found.
  let clientOption = this.currClient
  if clientOption.isSome:
    let selectedClientIndex = this.currTagClients.find(clientOption.get)
    let nextNormalClientIndex = this.currTagClients.findNormalClient(selectedClientIndex)
    return (selectedClientIndex, nextNormalClientIndex)
  return (-1, -1)

proc focusClient(
  this: Monitor,
  findNormalClient: (clients: openArray[Client], i: int) -> int
) =
  let result = this.findSelectedAndNextNormalClientIndexes(findNormalClient)
  if result.nextIndex >= 0:
    this.focusClient(this.currTagClients[result.nextIndex], true)

proc focusPreviousClient*(this: Monitor) =
  this.focusClient(client.findPreviousNormal)

proc focusNextClient*(this: Monitor) =
  this.focusClient(client.findNextNormal)

proc moveClient(
  this: Monitor,
  findNormalClient: (clients: openArray[Client], i: int) -> int
) =
  let indexes = this.findSelectedAndNextNormalClientIndexes(findNormalClient)
  if indexes.selectedIndex >= 0 and indexes.nextIndex >= 0:
    let temp = this.currTagClients[indexes.selectedIndex]
    this.currTagClients[indexes.selectedIndex] = this.currTagClients[indexes.nextIndex]
    this.currTagClients[indexes.nextIndex] = temp
    this.doLayout()
    this.focusClient(this.currTagClients[indexes.nextIndex], true)

proc moveClientPrevious*(this: Monitor) =
  this.moveClient(client.findPreviousNormal)

proc moveClientNext*(this: Monitor) =
  this.moveClient(client.findNextNormal)

proc toggleFullscreen*(this: Monitor, client: var Client) =
  if client.isFullscreen:
    discard XChangeProperty(
      this.display,
      client.window,
      $NetWMState,
      XA_ATOM,
      32,
      PropModeReplace,
      cast[Pcuchar]([]),
      0
    )
    client.isFullscreen = false
    client.isFloating = client.oldFloatingState
    client.borderWidth = client.oldBorderWidth
    client.x = client.oldX
    client.y = client.oldY
    client.width = client.oldWidth
    client.height = client.oldHeight
    client.adjustToState(this.display)
    this.doLayout()
  else:
    var arr = [$NetWMStateFullScreen]
    discard XChangeProperty(
      this.display,
      client.window,
      $NetWMState,
      XA_ATOM,
      32,
      PropModeReplace,
      cast[Pcuchar](arr.addr),
      1
    )
    client.isFullscreen = true
    client.oldFloatingState = client.isFloating
    client.oldBorderWidth = client.borderWidth
    client.borderWidth = 0
    client.isFloating = true
    client.resize(
      this.display,
      this.area.x,
      this.area.y,
      this.area.width,
      this.area.height
    )
    discard XRaiseWindow(this.display, client.window)

proc setFullscreen*(this: Monitor, client: var Client, fullscreen: bool) =
  ## Helper function for toggleFullscreen
  if fullscreen == client.isFullscreen:
    return
  this.toggleFullscreen(client)

proc toggleFullscreenForSelectedClient*(this: Monitor) =
  this.withSomeCurrClient(client):
    this.toggleFullscreen(client)

proc setFloating*(this: Monitor, client: Client, floating: bool) =
  ## Changes the client's floating state,
  ## performs the current layout for the current tag,
  ## and fits the client to its state attributes.
  if floating == client.isFloating:
    return
  client.isFloating = floating
  this.doLayout()
  if floating:
    if client.borderWidth == 0:
      client.oldBorderWidth = 0
      client.borderWidth = this.config.borderWidth
    client.adjustToState(this.display)

proc toggleFloatingForSelectedClient*(this: Monitor) =
  this.withSomeCurrClient(client):
    if client.isFixed or client.isFullscreen:
      return
    this.setFloating(client, not client.isFloating)

proc findNext*(monitors: openArray[Monitor], current: Monitor): int =
  ## Finds the next monitor index from index `i` (exclusive), iterating forward.
  ## This search will loop the array.
  for i in countup(monitors.low, monitors.high):
    if monitors[i] == current:
      if i == monitors.high:
        return monitors.low
      return i + 1
  return -1

proc findPrevious*(monitors: openArray[Monitor], current: Monitor): int =
  ## Finds the next monitor index from index `i` (exclusive), iterating backward.
  ## This search will loop the array.
  for i in countdown(monitors.high, monitors.low):
    if monitors[i] == current:
      if i == monitors.low:
        return monitors.high
      return i - 1
  return -1

proc find*(monitors: openArray[Monitor], x, y: int): int =
  ## Finds a monitor's index based on the pointer location.
  ## -1 is returned if no monitors contain the location.
  for i, monitor in monitors:
    if monitor.area.contains(x, y):
      return i
  return -1

