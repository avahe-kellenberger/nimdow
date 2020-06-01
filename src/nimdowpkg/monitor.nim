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
  layouts/layout,
  layouts/masterstacklayout,
  keys/keyutils,
  config/configloader

converter intToCint(x: int): cint = x.cint
converter intToCUint(x: int): cuint = x.cuint
converter cintToCUint(x: cint): cuint = x.cuint
converter intToCUchar(x: int): cuchar = x.cuchar
converter clongToCUlong(x: clong): culong = x.culong
converter toTBool(x: bool): TBool = x.TBool

const
  tagCount = 9
  masterSlots = 1

type
  Monitor* = ref object of RootObj
    display: PDisplay
    rootWindow: TWindow
    area*: Area
    config: Config
    taggedClients*: OrderedTable[Tag, seq[Client]]
    selectedTag*: Tag
    docks*: Table[TWindow, Client]
    layoutOffset: LayoutOffset

proc updateCurrentDesktopProperty(this: Monitor)
proc doLayout*(this: Monitor)

proc newMonitor*(display: PDisplay, rootWindow: TWindow, area: Area, currentConfig: Config): Monitor =
  result = Monitor()
  result.display = display
  result.rootWindow = rootWindow
  result.area = area
  result.config = currentConfig
  result.docks = initTable[TWindow, Client]()
  result.taggedClients = OrderedTable[Tag, seq[Client]]()
  for i in 0..<tagCount:
    let tag: Tag = newTag(
      id = i,
      layout = newMasterStackLayout(
        monitorArea = area,
        gapSize = currentConfig.gapSize,
        borderWidth = currentConfig.borderWidth,
        masterSlots = masterSlots
      )
    )
    result.taggedClients[tag] = @[]
  # View first tag by default
  for tag in result.taggedClients.keys():
    result.selectedTag = tag
    break

  result.updateCurrentDesktopProperty()

proc getMonitorAreas*(display: PDisplay, rootWindow: TWindow): seq[Area] =
  var number: cint
  var screenInfo =
    cast[ptr UncheckedArray[TXineramaScreenInfo]]
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
      (displayHeight - strut.bottom).int,
      strut.bottomEndX - strut.bottomStartX + 1,
      strut.bottom
    )

  else:
    echo "ERROR: No invalid strut!"
  return (0, 0, 0.uint, 0.uint)

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
  if this.currClient.isNone:
    return
  var client: Client = this.currClient.get
  body

proc find*(this: Monitor, window: TWindow): Option[Client] =
  ## Finds a client based on its window property.
  for tag, clients in this.taggedClients.pairs:
    let index = clients.find(window)
    if index >= 0:
      return clients[index].option
  return none(Client)

proc updateCurrentDesktopProperty(this: Monitor) =
  # TODO: Fix this when we determine how to display tags in a multihead environment.
  var data: array[1, clong] = [this.selectedTag.id]
  discard XChangeProperty(this.display,
                          this.rootWindow,
                          $NetCurrentDesktop,
                          XA_CARDINAL,
                          32,
                          PropModeReplace,
                          cast[Pcuchar](data[0].addr),
                          1)

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

proc updateLayoutOffset*(this: Monitor) =
  this.layoutOffset = this.docks.calcLayoutOffset(this.area.width, this.area.height)
  this.doLayout()

proc focusWindow*(this: Monitor, window: TWindow) =
  discard XSetInputFocus(
    this.display,
    window,
    RevertToPointerRoot,
    CurrentTime
  )

proc ensureWindowFocus*(this: Monitor) =
  ## Ensures a window is selected on the current tag.
  if this.currTagClients.len == 0:
    this.focusWindow(this.rootWindow)
  else:
    if this.currClient.isSome:
      this.focusWindow(this.currClient.get.window)
    elif this.selectedTag.previouslySelectedClient.isSome:
      this.focusWindow(this.selectedTag.previouslySelectedClient.get.window)
    else:
      # Find the first normal client
      let clientIndex = this.currTagClients.findNextNormal(-1)
      if clientIndex >= 0:
        this.focusWindow(this.currTagClients[clientIndex].window)
      else:
        this.focusWindow(this.rootWindow)

proc addWindowToClientListProperty*(this: Monitor, window: TWindow) =
  ## Adds the window to _NET_CLIENT_LIST
  discard XChangeProperty(this.display,
                          this.rootWindow,
                          $NetClientList,
                          XA_WINDOW,
                          32,
                          PropModeAppend,
                          cast[Pcuchar](window.unsafeAddr),
                          1)

proc updateClientList(this: Monitor) =
  discard XDeleteProperty(this.display, this.rootWindow, $NetClientList)
  for clients in this.taggedClients.values:
    for client in clients:
      this.addWindowToClientListProperty(client.window)
  for window in this.docks.keys:
    this.addWindowToClientListProperty(window)

proc setActiveWindowProperty*(this: Monitor, window: TWindow) =
  discard XChangeProperty(
      this.display,
      this.rootWindow,
      $NetActiveWindow,
      XA_WINDOW,
      32,
      PropModeReplace,
      cast[Pcuchar](window.unsafeAddr),
      1)

proc deleteActiveWindowProperty(this: Monitor) =
  discard XDeleteProperty(this.display, this.rootWindow, $NetActiveWindow)

proc doLayout*(this: Monitor) =
  ## Revalidates the current layout of the viewed tag(s).
  this.selectedTag.layout.arrange(
    this.display,
    this.currTagClients,
    this.layoutOffset
  )

proc removeWindowFromTag(this: Monitor, tag: Tag, clientIndex: int) =
  let client = this.taggedClients[tag][clientIndex]
  this.taggedClients[tag].delete(clientIndex)
  tag.clearSelectedClient(client)
  # If the previouslySelectedClient is destroyed, select the first window (or none).
  if tag.isPreviouslySelectedClient(client):
    if this.taggedClients[tag].len == 0:
      tag.previouslySelectedClient = none(Client)
    else:
      # Find and assign the first normal client as "previouslySelectedClient"
      let nextNormalIndex = this.taggedClients[tag].findNextNormal(-1)
      if nextNormalIndex >= 0:
        tag.previouslySelectedClient = this.taggedClients[tag][nextNormalIndex].option

proc removeWindowFromTagTable*(this: Monitor, window: TWindow): bool =
  ## Removes a window from the tag table on this monitor.
  ## Returns if the window was removed from the table.
  result = false
  for tag, clients in this.taggedClients.pairs:
    let clientIndex = clients.find(window)
    if clientIndex >= 0:
      this.removeWindowFromTag(tag, clientIndex) 
      result = true

proc removeWindow*(this: Monitor, window: TWindow): bool =
  ## Removes a window (could be in the tag table or a dock).
  ## Returns if the window was removed.
  ## After a window is removed, you should typically call
  ## doLayout and ensureWindowFocus (unless you have a specific use case).
  result = false
  var dock: Client
  if this.docks.pop(window, dock):
    this.updateLayoutOffset()
  else:
    result = this.removeWindowFromTagTable(window)
    this.deleteActiveWindowProperty()
  
  this.updateClientList()

proc updateWindowTagAtom*(this: Monitor, window: TWindow, tag: Tag) =
  # TODO: We should probably define our own per-monitor tag atoms
  let data: clong = this.selectedTag.id.clong
  discard XChangeProperty(this.display,
                          window,
                          $NetWMDesktop,
                          XA_CARDINAL,
                          32,
                          PropModeReplace,
                          cast[Pcuchar](data.unsafeAddr),
                          1)

proc destroySelectedWindow*(this: Monitor) =
  var selectedWin: TWindow
  var selectionState: cint
  discard XGetInputFocus(this.display, addr(selectedWin), addr(selectionState))
  var event = TXEvent()
  event.xclient.theType = ClientMessage
  event.xclient.window = selectedWin
  event.xclient.message_type = XInternAtom(this.display, "WM_PROTOCOLS", true)
  event.xclient.format = 32
  event.xclient.data.l[0] = ($WMDelete).cint
  event.xclient.data.l[1] = CurrentTime
  discard XSendEvent(this.display, selectedWin, false, NoEventMask, addr(event))
  discard XDestroyWindow(this.display, selectedWin)

proc moveClientToTag*(this: Monitor, client: Client, destinationTag: Tag) =
  for tag, clients in this.taggedClients.mpairs:
    # This assumes the client is being moved from the current tag to another tag. 
    if tag == destinationTag:
      if not clients.contains(client):
        clients.add(client)
        this.updateWindowTagAtom(client.window, destinationTag)
        tag.setSelectedClient(client)
        discard XUnmapWindow(this.display, client.window)
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

proc moveSelectedWindowToTag*(this: Monitor, tag: Tag) =
  if this.currClient.isSome:
    this.moveClientToTag(
      this.currClient.get,
      tag
    )

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
    discard XUnmapWindow(this.display, client.window)

  this.selectedTag = tag
  this.doLayout()

  for client in (setNext - setCurrent).items:
    discard XMapWindow(this.display, client.window)
    # Ensure correct border color is set for each window
    let color =
      if this.selectedTag.isSelectedClient(client):
        this.config.borderColorFocused else:
          this.config.borderColorUnfocused
    discard XSetWindowBorder(this.display, client.window, color)

  discard XSync(this.display, false)

  # Select the "selected" client for the newly viewed tag
  if this.currClient.isSome:
    this.focusWindow(this.currClient.get.window)
  else:
    this.deleteActiveWindowProperty()

  this.updateCurrentDesktopProperty()

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
    this.focusWindow(
      this.currTagClients[result.nextIndex].window
    )

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
    this.focusWindow(this.currTagClients[indexes.nextIndex].window)

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
    client.adjustToState(this.display)
  else:
    # Don't invoke client.adjustToState here,
    # since we want to be able to return the client to its normal state
    # when/if this proc is invoked again.
    discard XSetWindowBorderWidth(this.display, client.window, 0)
    discard XMoveResizeWindow(
      this.display,
      client.window,
      this.area.x,
      this.area.y,
      this.area.width.cuint,
      this.area.height.cuint
    )
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

  client.isFullscreen = not client.isFullscreen
  # Ensure the window has focus
  this.focusWindow(client.window)
  this.doLayout()

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
    client.adjustToState(this.display)

proc toggleFloatingForSelectedClient*(this: Monitor) =
  this.withSomeCurrClient(client):
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
