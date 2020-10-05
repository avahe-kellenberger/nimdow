import
  x11 / [x, xlib, xinerama, xatom],
  tables,
  listutils,
  sequtils,
  strutils

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
    previousTag*: Tag
    layoutOffset: LayoutOffset
    taggedClients*: TaggedClients

proc doLayout*(this: Monitor, warpToClient: bool = true)
proc restack*(this: Monitor)
proc setSelectedClient*(this: Monitor, client: Client)
proc updateCurrentDesktopProperty(this: Monitor)
proc updateWindowTitle(this: Monitor, redrawBar: bool = true)

proc newMonitor*(display: PDisplay, rootWindow: Window, area: Area, currentConfig: Config): Monitor =
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

  # Dynamically calculate the smallest needed size.
  # Must be a power of 2.
  var initialSize: int = 2
  while initialSize < tagCount:
    initialSize *= 2

  result.taggedClients.selectedTags = initOrderedSet[TagID](initialSize)
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

template clientSelection*(this: Monitor): DoublyLinkedList[Client] =
  this.taggedClients.clientSelection

proc setConfig*(this: Monitor, config: Config) =
  this.config = config.windowSettings
  for tag in this.tags:
    tag.layout.gapSize = this.config.gapSize
    tag.layout.borderWidth = this.config.borderWidth

  this.layoutOffset = (config.barSettings.height, 0.uint, 0.uint, 0.uint)
  this.statusBar.setConfig(config.barSettings)
  this.doLayout()

proc updateWindowTitle(this: Monitor, redrawBar: bool = true) =
  ## Renders the title of the active window of the given monitor
  ## on the monitor's status bar.
  this.taggedClients.withSomeCurrClient(client):
    let title = this.display.getWindowName(client.window)
    this.statusBar.setActiveWindowTitle(title, redrawBar)

proc setSelectedClient*(this: Monitor, client: Client) =
  if client == nil:
    log "Attempted to set nil client as the selected client", lvlError
    return

  log $client.window
  let node: ClientNode = this.taggedClients.find(client.window)

  if node == nil:
    log "Attempted to select a client not on the current tags"
    return

  if client == this.taggedClients.currClient:
    log "Same client was selected"
    return

  this.taggedClients.withSomeCurrClient(c):
    discard XSetWindowBorder(
      this.display,
      c.window,
      this.config.borderColorUnfocused
    )

  discard XSetWindowBorder(
    this.display,
    client.window,
    this.config.borderColorFocused
  )

  this.clientSelection.remove(node)
  this.clientSelection.append(node)
  this.updateWindowTitle()

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
  var data: array[1, clong] = [this.taggedClients.findFirstSelectedTag.id.clong]
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
    if tagNumber < 1 or tagNumber > this.tags.len:
      raise newException(Exception, "Invalid tag number: " & tagNumber)

    return this.tags[tagNumber - 1]
  except:
    log "Invalid tag number from config: " & getCurrentExceptionMsg(), lvlError

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

# proc ensureWindowFocus(this: Monitor) =
#   ## Ensures a window is selected on the current tag.
#   if this.currTagClients.len == 0:
#     this.focusRootWindow()
#     this.statusBar.setSelectedClient(nil)
#   else:
#     if this.currClient != nil:
#       this.focusClient(this.currClient, true)
#     elif this.selectedTag.previouslySelectedClient != nil:
#       this.focusClient(this.selectedTag.previouslySelectedClient, true)
#     else:
#       # Find the first normal client
#       let clientIndex = this.currTagClients.findNextNormal(-1)
#       if clientIndex >= 0:
#         let client = this.currTagClients[clientIndex]
#         this.focusClient(client, true)
#       else:
#         this.focusRootWindow()
#         this.statusBar.setSelectedClient(nil)
#         this.statusBar.setActiveWindowTitle("")

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

proc doLayout*(this: Monitor, warpToClient: bool = true) =
  ## Revalidates the current layout of the viewed tag(s).
  let tag = this.taggedClients.findFirstSelectedTag()
  tag.layout.arrange(
    this.display,
    # TODO: we should pass an iterator? Maybe.
    this.taggedClients.findCurrentClients(),
    this.layoutOffset
  )
  this.restack()
  this.taggedClients.withSomeCurrClient(client):
    if warpToClient:
      this.display.warpTo(client)

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

# proc removeWindowFromTag(this: Monitor, tag: Tag, clientIndex: int) =
#   # TODO: Using clientIndex like this isn't good if it has to do with a certain tag.
#   let client = this.clients[clientIndex]
#   this.clients[tag].delete(clientIndex)
#   tag.clearSelectedClient(client)
#   if tag.selectedClient == nil:
#     if this.clients[tag].len > 0:
#       # Find and assign the first normal client as "previouslySelectedClient"
#       let nextNormalIndex = this.clients[tag].findNextNormal(-1)
#       if nextNormalIndex >= 0:
#         tag.previouslySelectedClient = this.clients[tag][nextNormalIndex]
#         tag.selectedClient = tag.previouslySelectedClient
#     else:
#       tag.setSelectedClient(nil)
#       this.statusBar.setSelectedClient(nil, false)
#       this.statusBar.setActiveWindowTitle("")

proc removeWindowFromTagTable*(this: Monitor, window: Window): bool =
  ## Removes a window from the tag table on this monitor.
  ## Returns if the window was removed from the table.
  result = this.taggedClients.removeByWindow(window)

  # If the removed client was the most recently selected, select the new tail.
  let client = this.taggedClients.currClient
  if client != nil:
    this.setSelectedClient(client)
    let title = this.display.getWindowName(client.window)
    this.statusBar.setActiveWindowTitle(title)

  # TODO: else, select rootWindow?

proc removeWindow*(this: Monitor, window: Window): bool =
  ## Returns if the window was removed.
  ## After a window is removed, you should typically call
  ## doLayout and ensureWindowFocus (unless you have a specific use case).
  result = this.removeWindowFromTagTable(window)
  this.deleteActiveWindowProperty()
  this.updateClientList()

proc addClientToTags*(this: Monitor, client: var Client, tagIDs: varargs[TagID]) =
  for id in tagIDs:
    client.tagIDs.incl(id)

proc addClientToSelectedTags*(this: Monitor, client: var Client) =
  let selectedTags: OrderedSet[TagID] = this.selectedTags
  let tagIDs = toSeq(selectedTags.items)
  this.addClientToTags(client, tagIDs)

proc addClient*(this: Monitor, client: var Client) =
  this.clients.append(client)
  this.clientSelection.append(client)
  this.addClientToSelectedTags(client)

proc moveClientToTag*(this: Monitor, client: Client, destinationTag: Tag) =
  if destinationTag.id in client.tagIDs:
    return

  # Change client tags to only destinationTag id.
  client.tagIDs.clear()
  client.tagIDs.incl(destinationTag.id)

  if destinationTag.id in this.selectedTags:
    this.setSelectedClient(client)
    this.doLayout()
    # this.ensureWindowFocus()

  if this.taggedClients.findCurrentClients.len == 0:
    this.deleteActiveWindowProperty()
    this.statusBar.setActiveWindowTitle("", false)
  this.redrawStatusBar()

proc moveSelectedWindowToTag*(this: Monitor, tag: Tag) =
  if this.taggedClients.currClient != nil:
    this.moveClientToTag(this.taggedClients.currClient, tag)

proc setSelectedTags*(this: Monitor, tagIDs: varargs[TagID]) =
  ## Views the given tags.

  # Select only the given tags
  this.selectedTags.clear()
  for id in tagIDs:
    this.selectedTags.incl(id)

  # TODO: The code below can be reused to view multiple tags at once

  for client in this.clients.items:
    if client.tagIDs.anyIt(this.selectedTags.contains(it)):
      client.show(this.display)
    else:
      client.hide(this.display)

  for node in this.taggedClients.currClientsSelectionNewToOldIter:
    discard XSetWindowBorder(this.display, node.value.window, this.config.borderColorUnfocused)

  this.doLayout()

  discard XSync(this.display, false)

  if this.taggedClients.currClient != nil:
    this.focusClient(this.taggedClients.currClient, true)
  else:
    this.deleteActiveWindowProperty()
    this.statusBar.setActiveWindowTitle("", false)

  this.updateCurrentDesktopProperty()
  this.statusBar.redraw()

proc focusNextClient*(
  this: Monitor,
  warpToClient: bool,
  clientsIter: iterator(this: TaggedClients): ClientNode
) =
  ## Focuses the next client in the stack.
  for node in clientsIter(this.taggedClients):
    if node != nil:
      this.setSelectedClient(node.value)
    break

proc focusNextClient*(
  this: Monitor,
  warpToClient: bool
) =
  ## Focuses the next client in the stack.
  this.focusNextClient(warpToClient, currClientsIter)

proc focusPreviousClient*(this: Monitor, warpToClient: bool) =
  ## Focuses the previous client in the stack.
  this.focusNextClient(warpToClient, currClientsReverseIter)

proc moveClientNext*(
  this: Monitor,
  clientsIter: iterator(this: TaggedClients): ClientNode
) =
  ## Moves the client to the next position in the stack.
  var currentNode = this.taggedClients.currClientNode
  if currentNode == nil or currentNode.value == nil:
    return

  # TODO: When nim allows it, we can change this.
  var node: ClientNode
  for n in this.taggedClients.clientsIter:
    node = n
    let client = node.value
    if not client.isFloating and not client.isFixed:
      this.clients.swap(node, currentNode)
      this.doLayout()
      this.display.warpTo(this.taggedClients.currClient)
      break

proc moveClientNext*(this: Monitor) =
  ## Moves the client to the next position in the stack.
  this.moveClientNext(currClientsIter)

proc moveClientPrevious*(this: Monitor) =
  ## Moves the client to the previous position in the stack.
  this.moveClientNext(currClientsReverseIter)

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
  ## Finds a monitor's index based on the pointer location.
  ## -1 is returned if no monitors contain the location.
  for i, monitor in monitors:
    if monitor.area.contains(x, y):
      return i
  return -1

