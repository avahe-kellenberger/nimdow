import
  sugar,
  options,
  tables,
  sets,
  strutils,
  x11 / [x, xlib, xutil, xatom],
  client,
  xatoms,
  tag,
  area,
  config/config,
  event/xeventmanager,
  keys/keyutils,
  layouts/layout,
  layouts/masterstacklayout

converter intToCint(x: int): cint = x.cint
converter intToCUint(x: int): cuint = x.cuint
converter cintToCUint(x: cint): cuint = x.cuint
converter intToCUchar(x: int): cuchar = x.cuchar
converter clongToCUlong(x: clong): culong = x.culong
converter toTBool(x: bool): TBool = x.TBool
converter toBool(x: TBool): bool = x.bool

const wmName = "nimdow"
const tagCount = 9

# TODO: Should load these from settings
const borderColorFocused = 0x519f50
const borderColorUnfocused = 0x1c1b19
const borderWidth = 1

type
  WindowManager* = ref object
    display*: PDisplay
    rootWindow*: TWindow
    eventManager: XEventManager
    # Tags
    taggedClients: OrderedTable[Tag, seq[Client]]
    selectedTag: Tag
    docks: Table[TWindow, Dock]
    layoutOffset: LayoutOffset
    # Atoms
    wmAtoms: array[ord(WMLast), TAtom]
    netAtoms: array[ord(NetLast), TAtom]
    xAtoms: array[ord(XLast), TAtom]

proc initListeners(this: WindowManager)
proc updateCurrentDesktopProperty(this: WindowManager)
proc openDisplay(): PDisplay
proc configureConfigActions*(this: WindowManager)
proc configureRootWindow(this: WindowManager): TWindow
proc getAtom(this: WindowManager, id: NetAtom): TAtom
proc getAtom(this: WindowManager, id: WMAtom): TAtom
proc removeWindow(this: WindowManager, window: TWindow)
proc removeWindowFromTagTable(this: WindowManager, window: TWindow)
proc doLayout(this: WindowManager)
proc updateLayoutOffset(this: WindowManager)
# Custom WM actions
proc viewTag(this: WindowManager, tag: Tag)
proc keycodeToTag(this: WindowManager, keycode: int): Tag
proc focusNextClient(this: WindowManager)
proc focusPreviousClient(this: WindowManager)
proc moveClientPrevious(this: WindowManager)
proc moveClientNext(this: WindowManager)
proc moveClientToTag(this: WindowManager, client: Client, destinationTag: Tag)
proc toggleFullscreen(this: WindowManager, client: var Client)
proc destroySelectedWindow(this: WindowManager)
# XEvents
proc hookConfigKeys*(this: WindowManager)
proc errorHandler(display: PDisplay, error: PXErrorEvent): cint{.cdecl.}
proc onConfigureRequest(this: WindowManager, e: TXConfigureRequestEvent)
proc getProperty[T](this: WindowManager, window: TWindow, property: TAtom, kind: typedesc[T]): Option[T]
proc onClientMessage(this: WindowManager, e: TXClientMessageEvent)
proc onMapRequest(this: WindowManager, e: TXMapRequestEvent)
proc onEnterNotify(this: WindowManager, e: TXCrossingEvent)
proc onFocusIn(this: WindowManager, e: TXFocusChangeEvent)

proc newWindowManager*(eventManager: XEventManager): WindowManager =
  result = WindowManager()
  result.display = openDisplay()
  result.rootWindow = result.configureRootWindow()
  result.eventManager = eventManager
  result.docks = initTable[TWindow, Dock]()
  result.wmAtoms = xatoms.getWMAtoms(result.display)
  result.netAtoms = xatoms.getNetAtoms(result.display)
  result.xAtoms = xatoms.getXAtoms(result.display)
  result.initListeners()

  block tags:
    result.taggedClients = OrderedTable[Tag, seq[Client]]()
    for i in 0..<tagCount:
      let tag: Tag = newTag(
        id = i,
        layout = newMasterStackLayout(
          gapSize = 48,
          borderWidth = borderWidth,
          masterSlots = 1
        )
      )
      result.taggedClients[tag] = @[]
    # View first tag by default
    for tag in result.taggedClients.keys():
      result.selectedTag = tag
      break

  # Supporting window for NetWMCheck
  let ewmhWindow = XCreateSimpleWindow(result.display, result.rootWindow, 0, 0, 1, 1, 0, 0, 0)

  discard XChangeProperty(result.display,
                          result.rootWindow, 
                          result.getAtom(NetSupportingWMCheck),
                          XA_WINDOW,
                          32,
                          PropModeReplace,
                          cast[Pcuchar](ewmhWindow.unsafeAddr),
                          1)  

  discard XChangeProperty(result.display,
                          ewmhWindow,
                          result.getAtom(NetSupportingWMCheck),
                          XA_WINDOW,
                          32,
                          PropModeReplace,
                          cast[Pcuchar](ewmhWindow.unsafeAddr),
                          1)

  discard XChangeProperty(result.display,
                          ewmhWindow, 
                          result.getAtom(NetWMName),
                          XInternAtom(result.display, "UTF8_STRING", false),
                          8,
                          PropModeReplace,
                          cast[Pcuchar](wmName),
                          wmName.len)

  discard XChangeProperty(result.display,
                          result.rootWindow, 
                          result.getAtom(NetWMName),
                          XInternAtom(result.display, "UTF8_STRING", false),
                          8,
                          PropModeReplace,
                          cast[Pcuchar](wmName),
                          wmName.len)

  discard XChangeProperty(result.display,
                          result.rootWindow, 
                          result.getAtom(NetSupported),
                          XA_ATOM,
                          32,
                          PropModeReplace,
                          cast[Pcuchar](result.netAtoms.unsafeAddr),
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
                            result.getAtom(NetNumberOfDesktops),
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
                     result.getAtom(NetDesktopNames))

  block setDesktopViewport:
    let data: array[2, clong] = [0, 0]
    discard XChangeProperty(result.display,
                            result.rootWindow,
                            result.getAtom(NetDesktopViewport),
                            XA_CARDINAL,
                            32,
                            PropModeReplace,
                            cast[Pcuchar](data.unsafeAddr),
                            2)

  result.updateCurrentDesktopProperty()


template currTagClients(this: WindowManager): untyped =
  ## Grabs the windows on the current tag.
  ## This is used like an alias, e.g.:
  ## `let clients = this.taggedClients[this.selectedTags]`
  ## `clients` would be a copy of the collection.
  this.taggedClients[this.selectedTag]

proc initListeners(this: WindowManager) =
  discard XSetErrorHandler(errorHandler)
  this.eventManager.addListener((e: TXEvent) => onConfigureRequest(this, e.xconfigurerequest), ConfigureRequest)
  this.eventManager.addListener((e: TXEvent) => onClientMessage(this, e.xclient), ClientMessage)
  this.eventManager.addListener((e: TXEvent) => onMapRequest(this, e.xmaprequest), MapRequest)
  this.eventManager.addListener((e: TXEvent) => onEnterNotify(this, e.xcrossing), EnterNotify)
  this.eventManager.addListener((e: TXEvent) => onFocusIn(this, e.xfocus), FocusIn)
  this.eventManager.addListener(
    (e: TXEvent) =>
      removeWindow(this, e.xdestroywindow.window),
      DestroyNotify
  )

proc updateCurrentDesktopProperty(this: WindowManager) =
  var data: array[1, clong] = [this.selectedTag.id]
  discard XChangeProperty(this.display,
                          this.rootWindow,
                          this.getAtom(NetCurrentDesktop),
                          XA_CARDINAL,
                          32,
                          PropModeReplace,
                          cast[Pcuchar](data[0].addr),
                          1)

proc focusWindow(this: WindowManager, window: TWindow) =
  discard XSetInputFocus(
    this.display,
    window,
    RevertToPointerRoot,
    CurrentTime
  )

proc ensureWindowFocus(this: WindowManager) =
  ## Ensures a window is selected on the current tag.
  if this.currTagClients.len == 0:
    this.focusWindow(this.rootWindow)
  else:
    if this.selectedTag.selectedClient.isSome:
      this.focusWindow(this.selectedTag.selectedClient.get.window)
    elif this.selectedTag.previouslySelectedClient.isSome:
      this.focusWindow(this.selectedTag.selectedClient.get.window)
    else:
      let clientIndex = this.currTagClients.findNextNormal()
      if clientIndex >= 0:
        this.focusWindow(this.currTagClients[clientIndex].window)
      else:
        this.focusWindow(this.rootWindow)

proc addWindowToClientList(this: WindowManager, window: TWindow) =
  ## Adds the window to _NET_CLIENT_LIST
  discard XChangeProperty(this.display,
                          this.rootWindow,
                          this.getAtom(NetClientList),
                          XA_WINDOW,
                          32,
                          PropModeAppend,
                          cast[Pcuchar](window.unsafeAddr),
                          1)

proc updateClientList(this: WindowManager) =
  discard XDeleteProperty(this.display, this.rootWindow, this.getAtom(NetClientList))
  for clients in this.taggedClients.values:
    for client in clients:
      this.addWindowToClientList(client.window)
  for window in this.docks.keys:
    this.addWindowToClientList(window)

proc setActiveWindowProperty(this: WindowManager, window: TWindow) =
  discard XChangeProperty(
      this.display,
      this.rootWindow,
      this.getAtom(NetActiveWindow),
      XA_WINDOW,
      32,
      PropModeReplace,
      cast[Pcuchar](window.unsafeAddr),
      1)

proc deleteActiveWindowProperty(this: WindowManager) =
  discard XDeleteProperty(this.display, this.rootWindow, this.getAtom(NetActiveWindow))

proc removeWindow(this: WindowManager, window: TWindow) =
  var dock: Dock
  if this.docks.pop(window, dock):
    this.updateLayoutOffset()
    this.doLayout()
  else:
    this.removeWindowFromTagTable(window)
    this.deleteActiveWindowProperty()
  
  this.updateClientList()

proc removeWindowFromTag(this: WindowManager, tag: Tag, clientIndex: int) =
  let client = this.taggedClients[tag][clientIndex]
  this.taggedClients[tag].delete(clientIndex)
  tag.clearSelectedClient(client)
  # If the previouslySelectedClient is destroyed, select the first window (or none).
  if tag.isPreviouslySelectedClient(client):
    if this.taggedClients[tag].len == 0:
      tag.previouslySelectedClient = none(Client)
    else:
      # Find and assign the next normal client as "previouslySelectedClient"
      let nextNormalIndex = this.taggedClients[tag].findNextNormal()
      if nextNormalIndex >= 0:
        tag.previouslySelectedClient = this.taggedClients[tag][nextNormalIndex].option

  # Set currently selected window as previouslySelectedClient
  tag.selectedClient = tag.previouslySelectedClient

proc removeWindowFromTagTable(this: WindowManager, window: TWindow) =
  for tag, clients in this.taggedClients.pairs:
    let clientIndex: int = clients.find(window)
    if clientIndex >= 0:
      this.removeWindowFromTag(tag, clientIndex) 
  this.doLayout()
  this.ensureWindowFocus()

proc doLayout(this: WindowManager) =
  ## Revalidates the current layout of the viewed tag(s).
  this.selectedTag.layout.arrange(
    this.display,
    this.currTagClients,
    this.layoutOffset
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
  windowAttribs.event_mask = SubstructureRedirectMask or PropertyChangeMask

  # Listen for events on the root window
  discard XChangeWindowAttributes(
    this.display,
    result,
    CWEventMask or CWCursor,
    addr(windowAttribs)
  )
  discard XSync(this.display, false)

proc configureConfigActions*(this: WindowManager) =
  ## Maps available user configuration options to window manager actions.
  config.configureAction("goToTag", (keycode: int) => this.viewTag(this.keycodeToTag(keycode)))
  config.configureAction("focusNext", (keycode: int) => this.focusNextClient())
  config.configureAction("focusPrevious", (keycode: int) => this.focusPreviousClient())
  config.configureAction("moveWindowPrevious", (keycode: int) => this.moveClientPrevious())
  config.configureAction("moveWindowNext", (keycode: int) => this.moveClientNext())
  config.configureAction("moveWindowToTag",
    proc(keycode: int) = 
      if this.selectedTag.selectedClient.isSome:
        this.moveClientToTag(
          this.selectedTag.selectedClient.get,
          this.keycodeToTag(keycode)
        )
  )

  config.configureAction("toggleFullscreen",
    proc(keycode: int) =
      if this.selectedTag.selectedClient.isSome:
        this.toggleFullscreen(this.selectedTag.selectedClient.get)
  )
  config.configureAction("destroySelectedWindow", (keycode: int) => this.destroySelectedWindow())

proc hookConfigKeys*(this: WindowManager) =
  # Grab key combos defined in the user's config
  for keyCombo in config.KeyComboTable.keys():
    discard XGrabKey(
      this.display,
      keyCombo.keycode,
      keyCombo.modifiers,
      this.rootWindow,
      true,
      GrabModeAsync,
      GrabModeAsync
    )

####################
## Custom Actions ##
####################

proc viewTag(this: WindowManager, tag: Tag) =
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
    let color = if this.selectedTag.isSelectedClient(client): borderColorFocused else: borderColorUnfocused
    discard XSetWindowBorder(this.display, client.window, color)

  discard XSync(this.display, false)

  # Select the "selected" client for the newly viewed tag
  if this.selectedTag.selectedClient.isSome:
    this.focusWindow(this.selectedTag.selectedClient.get.window)
  else:
    this.deleteActiveWindowProperty()

  this.updateCurrentDesktopProperty()

proc keycodeToTag(this: WindowManager, keycode: int): Tag =
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

proc findSelectedAndNextNormalClientIndexes(
  this: WindowManager,
  findNormalClient: proc(clients: openArray[Client], i: int): int
): tuple[selectedIndex, nextIndex: int] =
  ## Finds the index of the currently selected client in currTagClients,
  ## and the index result of findNormalClient.
  ## Either value can be -1 if not found.
  let clientOption = this.selectedTag.selectedClient
  if clientOption.isSome:
    let selectedClientIndex = this.currTagClients.find(clientOption.get)
    let nextNormalClientIndex = this.currTagClients.findNormalClient(selectedClientIndex)
    return (selectedClientIndex, nextNormalClientIndex)
  return (-1, -1)

proc focusClient(
  this: WindowManager,
  findNormalClient: (clients: openArray[Client], i: int) -> int
) =
  let result = this.findSelectedAndNextNormalClientIndexes(findNormalClient)
  if result.nextIndex >= 0:
    this.focusWindow(
      this.currTagClients[result.nextIndex].window
    )

proc focusPreviousClient(this: WindowManager) =
  this.focusClient(client.findPreviousNormal)

proc focusNextClient(this: WindowManager) =
  this.focusClient(client.findNextNormal)

proc moveClient(
  this: WindowManager,
  findNormalClient: (clients: openArray[Client], i: int) -> int
) =
  let indexes = this.findSelectedAndNextNormalClientIndexes(findNormalClient)
  if indexes.selectedIndex >= 0 and indexes.nextIndex >= 0:
    let temp = this.currTagClients[indexes.selectedIndex]
    this.currTagClients[indexes.selectedIndex] = this.currTagClients[indexes.nextIndex]
    this.currTagClients[indexes.nextIndex] = temp
    this.doLayout()
    this.focusWindow(this.currTagClients[indexes.nextIndex].window)

proc moveClientPrevious(this: WindowManager) =
  this.moveClient(client.findPreviousNormal)

proc moveClientNext(this: WindowManager) =
  this.moveClient(client.findNextNormal)

proc updateWindowTagAtom(this: WindowManager, window: TWindow, destinationTag: Tag) =
  let data: clong = destinationTag.id.clong
  discard XChangeProperty(this.display,
                          window,
                          this.getAtom(NetWMDesktop),
                          XA_CARDINAL,
                          32,
                          PropModeReplace,
                          cast[Pcuchar](data.unsafeAddr),
                          1)

proc moveClientToTag(this: WindowManager, client: Client, destinationTag: Tag) =
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

proc destroySelectedWindow(this: WindowManager) =
  var selectedWin: TWindow
  var selectionState: cint
  discard XGetInputFocus(this.display, addr(selectedWin), addr(selectionState))
  var event = TXEvent()
  event.xclient.theType = ClientMessage
  event.xclient.window = selectedWin
  event.xclient.message_type = XInternAtom(this.display, "WM_PROTOCOLS", true)
  event.xclient.format = 32
  event.xclient.data.l[0] = this.getAtom(WMDelete).cint
  event.xclient.data.l[1] = CurrentTime
  discard XSendEvent(this.display, selectedWin, false, NoEventMask, addr(event))
  discard XDestroyWindow(this.display, selectedWin)

#####################
## XEvent Handling ##
#####################

proc getAtom(this: WindowManager, id: NetAtom): TAtom =
  this.netAtoms[ord(id)]

proc getAtom(this: WindowManager, id: WMAtom): TAtom =
  this.wmAtoms[ord(id)]

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

proc toggleFullscreen(this: WindowManager, client: var Client) =
  if client.isFullscreen:
    discard XChangeProperty(
      this.display,
      client.window,
      this.getAtom(NetWMState),
      XA_ATOM,
      32,
      PropModeReplace,
      cast[Pcuchar]([]),
      0
    )

    # Ensure the window has focus
    this.focusWindow(client.window)
  else:
    discard XSetWindowBorderWidth(this.display, client.window, 0)
    discard XMoveResizeWindow(
      this.display,
      client.window,
      0,
      0,
      XDisplayWidth(this.display, 0),
      XDisplayHeight(this.display, 0),
    )
    var arr = [this.getAtom(NetWMStateFullScreen)]   
    discard XChangeProperty(
      this.display,
      client.window,
      this.getAtom(NetWMState),
      XA_ATOM,
      32,
      PropModeReplace,
      cast[Pcuchar](arr.addr),
      1
    )
    discard XRaiseWindow(this.display, client.window)

  client.isFullscreen = not client.isFullscreen
  this.doLayout()

proc onConfigureRequest(this: WindowManager, e: TXConfigureRequestEvent) =
  # TODO: Handle docks as well?
  var clientOpt: Option[Client] = none(Client)
  for tag, clients in this.taggedClients.pairs:
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
      geometry.width = e.width
    if (e.value_mask and CWHeight) != 0:
      geometry.height = e.height
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
  if e.message_type == this.getAtom(NetWMStrutPartial):
    discard

  var clientIndex = this.currTagClients.find(e.window)
  if clientIndex < 0:
    return

  if e.message_type == this.getAtom(NetWMState):
    let fullscreenAtom = this.getAtom(NetWMStateFullScreen)
    if e.data.l[1] == fullscreenAtom or
      e.data.l[2] == fullscreenAtom:
        var client = this.currTagClients[clientIndex]
        this.toggleFullscreen(client)

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

proc updateLayoutOffset(this: WindowManager) =
  let screenWidth = XDisplayWidth(this.display, 0)
  let screenHeight = XDisplayHeight(this.display, 0)
  this.layoutOffset = this.docks.calcLayoutOffset(screenWidth.uint, screenHeight.uint)

proc updateWindowType(this: WindowManager, window: TWindow, windowAttr: TXWindowAttributes) =
  let
    stateOpt = this.getProperty(window, this.getAtom(NetWMState), TAtom)
    windowTypeOpt = this.getProperty(window, this.getAtom(NetWMWindowType), TAtom)

  let state: TAtom = if stateOpt.isSome: stateOpt.get else: None
  let windowType: TAtom = if windowTypeOpt.isSome: windowTypeOpt.get else: None

  if windowType == this.getAtom(NetWMWindowTypeDock):
    var dock = Dock(
      window: window,
      x: windowAttr.x,
      y: windowAttr.y,
      width: windowAttr.width.uint,
      height: windowAttr.height.uint
    )
    this.docks.add(window, dock)
    this.updateLayoutOffset()
  else:
    var client = newClient(window)
    this.currTagClients.add(client)
    this.updateWindowTagAtom(client.window, this.selectedTag)

    if state == this.getAtom(NetWMStateFullScreen):
      this.toggleFullscreen(client)

    client.isFloating = windowType != None and
                        windowType != this.getAtom(NetWMWindowTypeNormal) and
                        windowType != this.getAtom(NetWMWindowType)

proc manage(this: WindowManager, window: TWindow, windowAttr: TXWindowAttributes) =
  # Don't manage the same window twice.
  for tag, client in this.currTagClients:
    if client.window == window:
      return
  if this.docks.hasKey(window):
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

  this.addWindowToClientList(window)

  discard XMoveResizeWindow(this.display,
                            window,
                            windowAttr.x,
                            windowAttr.y,
                            windowAttr.width,
                            windowAttr.height)

  this.updateWindowType(window, windowAttr)
  this.doLayout()
  discard XMapWindow(this.display, window)

proc onMapRequest(this: WindowManager, e: TXMapRequestEvent) =
  var windowAttr: TXWindowAttributes
  # TODO: Error thrown here for gimp splash screen (BadValue)
  if XGetWindowAttributes(this.display, e.window, windowAttr.addr) == 0:
    return
  if windowAttr.override_redirect:
    return

  this.manage(e.window, windowAttr)

proc onEnterNotify(this: WindowManager, e: TXCrossingEvent) =
  if e.window != this.rootWindow:
    let clientIndex = this.currTagClients.find(e.window)
    if clientIndex >= 0 and this.currTagClients[clientIndex].isNormal:
      # Only focus normal windows
      discard XSetInputFocus(this.display, e.window, RevertToPointerRoot, CurrentTime)

proc onFocusIn(this: WindowManager, e: TXFocusChangeEvent) =
  if e.detail == NotifyPointer or
    e.window == this.rootWindow:
    return

  let clientIndex = this.currTagClients.find(e.window)
  if clientIndex < 0:
    return
  
  this.setActiveWindowProperty(e.window)

  let client = this.currTagClients[clientIndex]
  this.selectedTag.setSelectedClient(client)
  discard XSetWindowBorder(
    this.display,
    client.window,
    borderColorFocused
  )
  if this.selectedTag.previouslySelectedClient.isSome:
    let previous = this.selectedTag.previouslySelectedClient.get
    if previous.window != client.window:
      discard XSetWindowBorder(
        this.display,
        previous.window,
        borderColorUnfocused
      )

