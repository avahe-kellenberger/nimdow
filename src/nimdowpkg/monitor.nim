import
  x11 / [x, xlib, xinerama, xatom],
  tables,
  listutils,
  sequtils,
  strutils,
  sugar

import
  taggedclients,
  xatoms,
  area,
  layouts/layout,
  layouts/masterstacklayout,
  keys/keyutils,
  config/configloader,
  statusbar,
  logger

converter intToCint(x: int): cint = x.cint
converter intToCUint(x: int): cuint = x.cuint
converter cintToCUint(x: cint): cuint = x.cuint
converter intToCUchar(x: int): cuchar = x.cuchar
converter clongToCUlong(x: clong): culong = x.culong
converter toXBool(x: bool): XBool = x.XBool

const masterSlots = 1

type
  Monitor* = ref object of RootObj
    display: PDisplay
    rootWindow: Window
    statusBar*: StatusBar
    area*: Area
    config: WindowSettings
    # 0 indicates there's no previous tag ID.
    previousTagID*: TagID
    layoutOffset: LayoutOffset
    taggedClients*: TaggedClients

proc doLayout*(this: Monitor, warpToClient, focusCurrClient: bool = true)
proc restack*(this: Monitor)
proc setSelectedClient*(this: Monitor, client: Client)
proc updateCurrentDesktopProperty(this: Monitor)
proc updateWindowTitle(this: Monitor, redrawBar: bool = true)

proc newMonitor*(
  display: PDisplay,
  rootWindow: Window,
  area: Area,
  currentConfig: Config
): Monitor =
  result = Monitor()
  result.display = display
  result.rootWindow = rootWindow
  result.area = area
  let barArea: Area = (area.x, 0, area.width, currentConfig.barSettings.height)
  result.config = currentConfig.windowSettings
  result.layoutOffset = (barArea.height, 0.uint, 0.uint, 0.uint)

  result.taggedClients = newTaggedClients(tagCount)
  for i in 1..tagCount:
    let tag: Tag = newTag(
      id = i,
      layout = newMasterStackLayout(
        monitorArea = area,
        gapSize = currentConfig.windowSettings.gapSize,
        borderWidth = currentConfig.windowSettings.borderWidth,
        masterSlots = masterSlots
      )
    )
    result.taggedClients.tags.add(tag)

  # Select the 2nd tag as the previous tag.
  result.previousTagID = result.taggedClients.tags[1].id

  result.taggedClients.selectedTags = initOrderedSet[TagID](tagCount)
  result.taggedClients.selectedTags.incl(1)

  result.updateCurrentDesktopProperty()
  result.statusBar =
    display.newStatusBar(
      rootWindow,
      barArea,
      currentConfig.barSettings,
      result.taggedClients
    )

########################################################
#### Helper procs, iterators, templates, and macros ####
########################################################

template tags*(this: Monitor): seq[Tag] =
  this.taggedClients.tags

template selectedTags*(this: Monitor): OrderedSet[TagID] =
  this.taggedClients.selectedTags

template clients*(this: Monitor): DoublyLinkedList[Client] =
  this.taggedClients.clients

template clientSelection*(this: Monitor): seq[Client] =
  this.taggedClients.clientSelection

proc updateWindowBorders(this: Monitor) =
  for n in this.taggedClients.currClientsIter:
    let client = n.value
    if not client.isUrgent:
      discard XSetWindowBorder(
        this.display,
        n.value.window,
        this.config.borderColorUnfocused
      )

  this.taggedClients.withSomeCurrClient(c):
    if not c.isFixed and not c.isFullscreen:
      discard XSetWindowBorder(
        this.display,
        c.window,
        this.config.borderColorFocused
      )

proc setConfig*(this: Monitor, config: Config) =
  this.config = config.windowSettings
  for tag in this.tags:
    tag.layout.gapSize = this.config.gapSize
    tag.layout.borderWidth = this.config.borderWidth

  this.layoutOffset = (config.barSettings.height, 0.uint, 0.uint, 0.uint)
  this.statusBar.setConfig(config.barSettings)

  for client in this.taggedClients.clients:
    if client.borderWidth != 0:
      client.borderWidth = this.config.borderWidth
    client.oldBorderWidth = this.config.borderWidth
    if client.isFloating or client.isFixed:
      client.adjustToState(this.display)

  this.doLayout(false, false)

proc updateWindowTitle(this: Monitor, redrawBar: bool = true) =
  ## Renders the title of the active window of the given monitor
  ## on the monitor's status bar.
  let currClient = this.taggedClients.currClient
  var title: string
  if currClient != nil:
    title = this.display.getWindowName(currClient.window)
  this.statusBar.setActiveWindowTitle(title, redrawBar)

proc setSelectedClient*(this: Monitor, client: Client) =
  if client != nil:
    if client.isUrgent:
      client.setUrgent(this.display, false)

    if this.clients.find(client.window) == nil:
      log "Attempted to select a client not on the current tags"
      return

    this.taggedClients.selectClient(client.window)

  this.updateWindowTitle()
  this.updateWindowBorders()

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

proc updateCurrentDesktopProperty(this: Monitor) =
  let firstTag = this.taggedClients.findFirstSelectedTag
  if firstTag != nil:
    var data: array[1, clong] = [firstTag.id.clong]
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
  # TODO: Have a map of keycode to tagID and display character
  try:
    let tagNumber = parseInt(keycode.toString(this.display))
    if tagNumber < 1 or tagNumber > this.tags.len:
      raise newException(Exception, "Invalid tag number: " & tagNumber)

    return this.tags[tagNumber - 1]
  except:
    log "Invalid tag number from config: " & getCurrentExceptionMsg(), lvlError

proc focusClient*(this: Monitor, client: Client, warpToClient: bool) =
  this.setSelectedClient(client)

  if client.hasBeenMapped:
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
  for client in this.clients.items:
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

proc doLayout*(this: Monitor, warpToClient, focusCurrClient: bool = true) =
  ## Revalidates the current layout of the viewed tag(s).
  for client in this.clients.items:
    if client.tagIDs.anyIt(this.selectedTags.contains(it)):
      client.show(this.display)
    else:
      client.hide(this.display)

  let tag = this.taggedClients.findFirstSelectedTag()
  if tag != nil:
    tag.layout.arrange(
      this.display,
      this.taggedClients.findCurrentClients(),
      this.layoutOffset
    )

  this.restack()

  discard XSync(this.display, false)

  if focusCurrClient:
    if this.taggedClients.currClient != nil:
      this.focusClient(this.taggedClients.currClient, warpToClient)
    else:
      this.focusRootWindow()
      this.deleteActiveWindowProperty()
      this.statusBar.setActiveWindowTitle("", false)

  this.updateCurrentDesktopProperty()
  this.statusBar.redraw()

proc restack*(this: Monitor) =
  this.taggedClients.withSomeCurrClient(client):
    if client.isFloating:
      discard XRaiseWindow(this.display, client.window)

    var winChanges: XWindowChanges
    winChanges.stack_mode = Below
    winChanges.sibling = this.statusBar.barWindow
    for node in this.taggedClients.currClientsIter:
      let c = node.value
      if not c.isFloating and not client.isFullscreen:
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

proc removeWindowFromTagTable*(this: Monitor, window: Window): bool =
  ## Removes a window from the tag table on this monitor.
  ## Returns if the window was removed from the table.
  result = this.taggedClients.removeByWindow(window)
  this.deleteActiveWindowProperty()
  this.updateClientList()
  this.updateWindowTitle()

proc removeWindow*(this: Monitor, window: Window): bool =
  ## Returns if the window was removed.
  ## After a window is removed, you should typically call
  ## doLayout (unless you have a specific use case).
  return this.removeWindowFromTagTable(window)

proc toggleTagsForClient*(
  this: Monitor,
  client: var Client,
  tagIDs: varargs[TagID]
) =
  # Cache if the client was on the current tags.
  let wasOnCurrTags = client.tagIDs.anyIt(this.selectedTags.contains(it))

  var firstTagToggledOff: int = 0
  for id in tagIDs:
    if client.tagIDs.contains(id):
      if firstTagToggledOff == 0:
        firstTagToggledOff = id
      client.tagIDs.excl(id)
    else:
      client.tagIDs.incl(id)

  # Ensure the client is assigned at least one tag.
  if client.tagIDs.len == 0:
      client.tagIDs.incl(firstTagToggledOff.TagID)

  # Perform the layout if the client was removed from the current tags.
  if wasOnCurrTags and not client.tagIDs.anyIt(this.selectedTags.contains(it)):
    this.doLayout()

proc toggleSelectedTagsForClient*(this: Monitor, client: var Client) =
  let selectedTags: OrderedSet[TagID] = this.selectedTags
  let tagIDs = toSeq(selectedTags.items)
  this.toggleTagsForClient(client, tagIDs)

proc addClient*(this: Monitor, client: var Client) =
  this.clients.append(client)
  this.clientSelection.add(client)
  client.tagIDs.clear()
  this.toggleSelectedTagsForClient(client)

proc moveClientToTag*(this: Monitor, client: Client, destinationTag: Tag) =
  if client.tagIDs.len == 1 and destinationTag.id in client.tagIDs:
    return

  # Change client tags to only destinationTag id.
  client.tagIDs.clear()
  client.tagIDs.incl(destinationTag.id)

  this.doLayout()

  if destinationTag.id in this.selectedTags:
    this.setSelectedClient(client)
  else:
    this.setSelectedClient(this.taggedClients.currClient)

  if this.taggedClients.findCurrentClients.len == 0:
    this.deleteActiveWindowProperty()
    this.statusBar.setActiveWindowTitle("", false)
  this.redrawStatusBar()

proc moveSelectedWindowToTag*(this: Monitor, tag: Tag) =
  this.taggedClients.withSomeCurrClient(client):
    this.moveClientToTag(client, tag)

proc toggleTags*(this: Monitor, tagIDs: varargs[TagID]) =
  ## Views the given tags.

  for id in tagIDs:
    if this.selectedTags.contains(id):
      this.selectedTags.excl(id)
    else:
      this.selectedTags.incl(id)

  this.doLayout()

proc setSelectedTags*(this: Monitor, tagIDs: varargs[TagID]) =
  ## Views the given tags.

  # Select only the given tags
  this.selectedTags.clear()
  for id in tagIDs:
    this.selectedTags.incl(id)
  this.doLayout()

proc focusNextClient*(
  this: Monitor,
  warpToClient: bool,
  reversed: bool
) =
  ## Focuses the next client in the stack.
  let node = this.taggedClients.findNextCurrClient(this.taggedClients.currClient, reversed)
  if node != nil:
    this.focusClient(node.value, warpToClient)

proc focusNextClient*(this: Monitor, warpToClient: bool) =
  ## Focuses the next client in the stack.
  this.focusNextClient(warpToClient, false)

proc focusPreviousClient*(this: Monitor, warpToClient: bool) =
  ## Focuses the previous client in the stack.
  this.focusNextClient(warpToClient, true)

proc moveClientNext*(
  this: Monitor,
  reversed: bool
) =
  ## Moves the client to the next position in the stack.
  var currNode = this.taggedClients.currClientNode
  if currNode == nil:
    return

  var node = this.taggedClients.findNextCurrClient(
    currNode.value,
    reversed,
    (client: Client) => not client.isFloating and not client.isFixed
  )

  if node != nil and node.value != nil:
    swap(currNode, node)
    this.setSelectedClient(node.value)
    this.doLayout()

proc moveClientNext*(this: Monitor) =
  ## Moves the client to the next position in the stack.
  this.moveClientNext(false)

proc moveClientPrevious*(this: Monitor) =
  ## Moves the client to the previous position in the stack.
  this.moveClientNext(true)

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
  this.taggedClients.withSomeCurrClient(client):
    this.toggleFullscreen(client)

proc setFloating*(this: Monitor, client: Client, floating: bool) =
  ## Changes the client's floating state,
  ## performs the current layout for the current tag,
  ## and fits the client to its state attributes.
  if floating == client.isFloating:
    return

  client.oldFloatingState = client.isFloating
  client.isFloating = floating

  this.doLayout()

  if floating:
    if client.borderWidth == 0:
      client.oldBorderWidth = 0
      client.borderWidth = this.config.borderWidth
    if client.totalWidth() > this.area.width:
      client.width = this.area.width - client.borderWidth * 2
    if client.totalHeight() > this.area.height - this.statusBar.area.height:
      client.height = this.area.height - client.borderWidth * 2 - this.statusBar.area.height

    client.adjustToState(this.display)

proc toggleFloatingForSelectedClient*(this: Monitor) =
  this.taggedClients.withSomeCurrClient(client):
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
  ## Finds a monitor's index based on the given location.
  ## -1 is returned if no monitors contain the location.

  for i, monitor in monitors:
    if monitor.area.contains(x, y):
      return i

  var shortestDist = float.high
  # Find the closest monitor based on distance to its center.
  for i, monitor in monitors:
    let dist = min(shortestDist, monitor.area.distanceToCenterSquared(x, y))
    if dist < shortestDist:
      shortestDist = dist
      result = i

