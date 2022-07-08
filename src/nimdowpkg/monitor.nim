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
  config/configloader,
  keys/keyutils,
  statusbar,
  systray,
  logger

converter intToCint(x: int): cint = x.cint
converter intToCUint(x: int): cuint = x.cuint
converter cintToCUint(x: cint): cuint = x.cuint
converter intToCUchar(x: int): cuchar = x.cuchar
converter clongToCUlong(x: clong): culong = x.culong
converter toXBool(x: bool): XBool = x.XBool

type
  Monitor* = ref object of RootObj
    id*: MonitorID
    display: PDisplay
    rootWindow: Window
    statusBar*: StatusBar
    isStatusBarEnabled*: bool
    systray*: Systray
    area*: Area
    config: Config
    monitorSettings*: MonitorSettings
    windowSettings: WindowSettings
    previousTagID*: TagID
    layoutOffset*: LayoutOffset
    taggedClients*: TaggedClients

proc doLayout*(this: Monitor, warpToClient, focusCurrClient: bool = true)
proc updateMonitor*(this: Monitor)
proc restack*(this: Monitor)
proc setSelectedClient*(this: Monitor, client: Client)
proc updateCurrentDesktopProperty(this: Monitor)
proc updateWindowTitle(this: Monitor, redrawBar: bool = true)
proc setFullscreen*(this: Monitor, client: var Client, fullscreen: bool)

proc newMonitor*(
  id: MonitorID,
  display: PDisplay,
  rootWindow: Window,
  area: Area,
  currentConfig: Config
): Monitor =
  result = Monitor()
  result.id = id
  result.display = display
  result.rootWindow = rootWindow
  result.area = area
  result.config = currentConfig
  if currentConfig.monitorSettings.hasKey(id):
    result.monitorSettings = currentConfig.monitorSettings[id]
  else:
    result.monitorSettings = currentConfig.defaultMonitorSettings
  result.windowSettings = currentConfig.windowSettings
  result.taggedClients = newTaggedClients(tagCount)
  for i in 1..tagCount:
    let tagSetting = result.monitorSettings.tagSettings[i]
    let tag: Tag = newTag(
      id = i,
      layout = newMasterStackLayout(
        monitorArea = area,
        gapSize = result.monitorSettings.layoutSettings.gapSize,
        defaultWidth = tagSetting.defaultMasterWidthPercentage,
        borderWidth = currentConfig.windowSettings.borderWidth,
        masterSlots = tagSetting.numMasterWindows.uint,
        layoutOffset = result.layoutOffset,
        outerGap = result.monitorSettings.layoutSettings.outerGap
      )
    )
    result.taggedClients.tags.add(tag)

  # Select the 2nd tag as the previous tag.
  result.previousTagID = result.taggedClients.tags[1].id

  result.taggedClients.selectedTags = initOrderedSet[TagID](tagCount)
  result.taggedClients.selectedTags.incl(1)
  result.isStatusBarEnabled = true
  result.updateMonitor()

proc updateMonitor*(this: Monitor) =
  let barArea: Area = (this.area.x, this.area.y, this.area.width, this.monitorSettings.barSettings.height)
  this.layoutOffset = (barArea.height, 0.uint, 0.uint, 0.uint)


  this.updateCurrentDesktopProperty()
  this.statusBar =
    this.display.newStatusBar(
      this.rootWindow,
      barArea,
      this.monitorSettings.barSettings,
      this.taggedClients,
      this.monitorSettings.tagSettings
    )
  
  for i, tag in this.taggedClients.tags:
    tag.layout.monitorArea = this.area
  this.doLayout()


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

proc enableStatusBar*(this: Monitor) =
  this.layoutOffset = (this.statusBar.area.height, 0.uint, 0.uint, 0.uint)
  this.statusBar.show()
  if this.systray != nil:
    this.systray.show(this.display, this.area)
  this.isStatusBarEnabled = true
  this.doLayout()

proc disableStatusBar*(this: Monitor) =
  this.layoutOffset = (0.uint, 0.uint, 0.uint, 0.uint)
  this.statusBar.hide()
  if this.systray != nil:
    this.systray.hide(this.display, this.area)
  this.isStatusBarEnabled = false
  this.doLayout()

proc toggleStatusBar*(this: Monitor) =
  if this.isStatusBarEnabled:
    this.disableStatusBar()
  else:
    this.enableStatusBar()

proc updateWindowBorders(this: Monitor) =
  let currClient: Client = this.taggedClients.currClient
  for n in this.taggedClients.currClientsIter:
    let client = n.value
    if not client.isUrgent and client != currClient:
      discard XSetWindowBorder(
        this.display,
        n.value.window,
        this.windowSettings.borderColorUnfocused
      )

  if currClient != nil:
    if not currClient.isFixedSize and not currClient.isFullscreen:
      discard XSetWindowBorder(
        this.display,
        currClient.window,
        this.windowSettings.borderColorFocused
      )

proc setConfig*(this: Monitor, config: Config) =
  this.config = config
  this.windowSettings = config.windowSettings
  if config.monitorSettings.hasKey(this.id):
    this.monitorSettings = config.monitorSettings[this.id]
  else:
    this.monitorSettings = config.defaultMonitorSettings

  this.layoutOffset = (this.monitorSettings.barSettings.height, 0.uint, 0.uint, 0.uint)
  this.statusBar.setConfig(this.monitorSettings.barSettings, this.monitorSettings.tagSettings)

  for i, tag in this.tags:
    let tagSetting = this.monitorSettings.tagSettings[i + 1]
    tag.layout.gapSize = this.monitorSettings.layoutSettings.gapSize
    tag.layout.borderWidth = this.windowSettings.borderWidth
    tag.layout.masterSlots = tagSetting.numMasterWindows.uint
    let masterLayout = cast[MasterStackLayout](tag.layout)
    masterLayout.outerGap = this.monitorSettings.layoutSettings.outerGap
    masterLayout.defaultWidth = tagSetting.defaultMasterWidthPercentage
    masterLayout.setDefaultWidth(this.layoutOffset)

  for client in this.taggedClients.clients:
    if client.borderWidth != 0 or this.monitorSettings.layoutSettings.outerGap > 0:
      client.borderWidth = this.windowSettings.borderWidth
    client.oldBorderWidth = this.windowSettings.borderWidth
    if client.isFloating or client.isFixedSize:
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

proc keycodeToTagID*(this: Monitor, keycode: int): Option[TagID] =
  try:
    let tagNumber = parseInt(keycode.toString(this.display))
    if tagNumber < 1 or tagNumber > this.tags.len:
      raise newException(Exception, "Invalid tag number: " & $tagNumber)

    return this.tags[tagNumber - 1].id.option
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
  let tag = this.taggedClients.findFirstSelectedTag()
  if tag != nil:
    tag.layout.arrange(
      this.display,
      this.taggedClients.findCurrentClients(),
      this.layoutOffset
    )

  var topmostFullscreenClient: Client = nil
  for client in this.clientSelection.mitems:
    if client.tagIDs.anyIt(this.selectedTags.contains(it)):
      if client.needsFullscreen:
        topmostFullscreenClient = client
        client.isFullscreen = false
        client.needsFullscreen = false
        this.setFullscreen(client, true)
      elif client.isFullscreen:
        topmostFullscreenClient = client
        client.show(this.display)

  if topmostFullscreenClient == nil:
    # There are no fullscreen clients on viewable tags.
    if this.isStatusBarEnabled:
      this.statusBar.show()
    for client in this.clients.mitems:
      if client.tagIDs.anyIt(this.selectedTags.contains(it)):
        client.show(this.display)
      else:
        client.hide(this.display)
    if this.isStatusBarEnabled and this.systray != nil:
      this.systray.show(this.display, this.statusBar.area)
  else:
    for client in this.clients.mitems:
      # Only show the topmost fullscreen client.
      if client.window != topmostFullscreenClient.window:
        client.hide(this.display)

    if this.isStatusBarEnabled:
      this.statusBar.hide()

    if this.isStatusBarEnabled and this.systray != nil:
      this.systray.hide(this.display, this.area)
    this.focusClient(topmostFullscreenClient, true)

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

  this.statusBar.redraw()

proc toggleSelectedTagsForClient*(this: Monitor, client: var Client) =
  let selectedTags: OrderedSet[TagID] = this.selectedTags
  let tagIDs = toSeq(selectedTags.items)
  this.toggleTagsForClient(client, tagIDs)

proc addClient*(this: Monitor, client: var Client, assignToSelectedTags: bool = true) =
  this.clients.append(client)
  this.clientSelection.add(client)
  if assignToSelectedTags:
    client.tagIDs.clear()
    this.toggleSelectedTagsForClient(client)

  this.statusBar.redraw()

proc rotateClients*(this: Monitor) =
  let clientNode = this.taggedClients.findLastLayoutNode()
  this.clients.remove(clientNode)
  this.clients.prepend(clientNode)
  this.doLayout()

proc moveClientToTag*(this: Monitor, client: Client, destinationTagID: TagID) =
  if client.tagIDs.len == 1 and destinationTagID in client.tagIDs:
    return

  # Change client tags to only destinationTag id.
  client.tagIDs.clear()
  client.tagIDs.incl(destinationTagID)

  this.doLayout()

  if destinationTagID in this.selectedTags:
    this.setSelectedClient(client)
  else:
    this.setSelectedClient(this.taggedClients.currClient)

  if this.taggedClients.findCurrentClients.len == 0:
    this.deleteActiveWindowProperty()
    this.statusBar.setActiveWindowTitle("", false)
  this.redrawStatusBar()

proc moveSelectedWindowToTag*(this: Monitor, tagID: TagID) =
  this.taggedClients.withSomeCurrClient(client):
    this.moveClientToTag(client, tagID)

proc toggleTags*(this: Monitor, tagIDs: varargs[TagID]) =
  ## Views the given tags.

  for id in tagIDs:
    if this.selectedTags.contains(id):
      this.selectedTags.excl(id)
    else:
      this.selectedTags.incl(id)

  this.doLayout()

proc setSelectedTags*(this: Monitor, tagIDs: varargs[TagID], warpToClient: bool = true) =
  ## Views the given tags.

  # Select only the given tags
  this.selectedTags.clear()
  for id in tagIDs:
    this.selectedTags.incl(id)
  this.doLayout(warpToClient)

proc focusNextClient*(
  this: Monitor,
  warpToClient: bool,
  reversed: bool
) =
  ## Focuses the next client in the stack.
  let currClient = this.taggedClients.currClient
  if currClient != nil and currClient.isFullscreen:
    # Fullscreen clients should be the ONLY thing you interact with.
    return

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
    (client: Client) => not client.isFloating and not client.isFixedSize
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
    if this.taggedClients.currClientsContains(client):
      this.doLayout(false, true)
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
    if this.taggedClients.currClientsContains(client):
      discard XRaiseWindow(this.display, client.window)
      this.doLayout(false, true)

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
      client.borderWidth = this.windowSettings.borderWidth
    if client.totalWidth() > this.area.width:
      client.width = this.area.width - client.borderWidth * 2
    if client.totalHeight() > this.area.height - this.statusBar.area.height:
      client.height = this.area.height - client.borderWidth * 2 - this.statusBar.area.height

    client.adjustToState(this.display)

proc toggleFloatingForSelectedClient*(this: Monitor) =
  this.taggedClients.withSomeCurrClient(client):
    if client.isFixedSize or client.isFullscreen:
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

proc find*(monitors: OrderedTable[MonitorID, Monitor], x, y: int): tuple[index: int, monitor: Monitor] =
  ## Finds a monitor's index based on the given location.
  ## -1 is returned if no monitors contain the location.

  for i, monitor in monitors:
    if monitor.area.contains(x, y):
      return (i, monitor)

  var shortestDist = float.high
  # Find the closest monitor based on distance to its center.
  for i, monitor in monitors:
    let dist = min(shortestDist, monitor.area.distanceToCenterSquared(x, y))
    if dist < shortestDist:
      shortestDist = dist
      result = (i, monitor)
