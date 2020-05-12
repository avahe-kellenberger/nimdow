import
  sugar,
  options,
  tables,
  strutils,
  x11 / [x, xlib, xatom],
  client,
  xatoms,
  tag,
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
    tagTable: OrderedTable[Tag, seq[Client]]
    selectedTag: Tag
    # Atoms
    wmAtoms: array[ord(WMLast), TAtom]
    netAtoms: array[ord(NetLast), TAtom]
    xAtoms: array[ord(XLast), TAtom]

proc initListeners(this: WindowManager)
proc openDisplay(): PDisplay
proc configureConfigActions*(this: WindowManager)
proc configureRootWindow(this: WindowManager): TWindow
proc configureWindowMappingListeners(this: WindowManager, eventManager: XEventManager)
proc isInTagTable(this: WindowManager, window: TWindow): bool
proc addClientToSelectedTags(this: WindowManager, window: TWindow)
proc removeWindowFromTagTable(this: WindowManager, window: TWindow)
proc doLayout(this: WindowManager)
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
proc onClientMessage(this: WindowManager, e: TXClientMessageEvent)
proc onMapRequest(this: WindowManager, e: TXMapRequestEvent)
proc onEnterNotify(this: WindowManager, e: TXCrossingEvent)
proc onFocusIn(this: WindowManager, e: TXFocusChangeEvent)

proc newWindowManager*(eventManager: XEventManager): WindowManager =
  result = WindowManager()
  result.display = openDisplay()
  result.rootWindow = result.configureRootWindow()
  result.eventManager = eventManager
  result.wmAtoms = xatoms.getWMAtoms(result.display)
  result.netAtoms = xatoms.getNetAtoms(result.display)
  result.xAtoms = xatoms.getXAtoms(result.display)
  result.initListeners()

  block tags:
    result.tagTable = OrderedTable[Tag, seq[Client]]()
    for i in 1..9:
      let tag: Tag = newTag(
        id = i,
        layout = newMasterStackLayout(
          gapSize = 48,
          borderSize = 2,
          masterSlots = 1
        )
      )
      result.tagTable[tag] = @[]
    # View first tag by default
    for tag in result.tagTable.keys():
      result.selectedTag = tag
      break
    result.configureWindowMappingListeners(eventManager)

  let utf8string = XInternAtom(result.display, "UTF8_STRING", false)
  # Supporting window for NetWMCheck
  let wmcheckwin = XCreateSimpleWindow(result.display, result.rootWindow, 0, 0, 1, 1, 0, 0, 0)
  discard XChangeProperty(result.display, wmcheckwin, result.netAtoms[ord(NetWMCheck)], XA_WINDOW, 32,
                          PropModeReplace, cast[Pcuchar](wmcheckwin.unsafeAddr), 1)
  discard XChangeProperty(result.display, wmcheckwin, result.netAtoms[ord(NetWMName)], utf8string, 8,
                          PropModeReplace, cast[Pcuchar]("nimdow"), 3)
  discard XChangeProperty(result.display, result.rootWindow, result.netAtoms[ord(NetWMCheck)], XA_WINDOW, 32,
                          PropModeReplace, cast[Pcuchar](wmcheckwin.unsafeAddr), 1)
  # EWMH support per view
  discard XChangeProperty(result.display, result.rootWindow, result.netAtoms[ord(NetSupported)], XA_ATOM, 32,
                          PropModeReplace, cast[Pcuchar](result.netAtoms.unsafeAddr), ord(NetLast))
  discard XDeleteProperty(result.display, result.rootWindow, result.netAtoms[ord(NetClientList)]);

template selectedClients(this: WindowManager): untyped =
  ## Grabs the currently selected tags.
  ## This is used like an alias; if one uses the following:
  ## `let clients = this.tagTable[this.selectedTags]`
  ## `clients` would be a copy of the collection.
  this.tagTable[this.selectedTag]

proc initListeners(this: WindowManager) =
  discard XSetErrorHandler(errorHandler)
  this.eventManager.addListener((e: TXEvent) => onConfigureRequest(this, e.xconfigurerequest), ConfigureRequest)
  this.eventManager.addListener((e: TXEvent) => onClientMessage(this, e.xclient), ClientMessage)
  this.eventManager.addListener((e: TXEvent) => onMapRequest(this, e.xmaprequest), MapRequest)
  this.eventManager.addListener((e: TXEvent) => onEnterNotify(this, e.xcrossing), EnterNotify)
  this.eventManager.addListener((e: TXEvent) => onFocusIn(this, e.xfocus), FocusIn)

proc configureWindowMappingListeners(this: WindowManager, eventManager: XEventManager) =
  eventManager.addListener(
    (proc(e: TXEvent) =
      if not e.xmap.override_redirect:
        addClientToSelectedTags(this, e.xmap.window)
    ),
    MapNotify
  )
  eventManager.addListener(
    proc (e: TXEvent) =
      removeWindowFromTagTable(this, e.xdestroywindow.window), DestroyNotify)

proc focusWindow(this: WindowManager, window: TWindow) =
  discard XSetInputFocus(this.display, window, RevertToPointerRoot, CurrentTime)

proc isInTagTable(this: WindowManager, window: TWindow): bool =
  for clients in this.tagTable.values():
    for client in clients:
      if client.window == window:
        return true
  return false

proc addClientToSelectedTags(this: WindowManager, window: TWindow) =
  if this.selectedClients.find(window) < 0:
    let client = newClient(window)
    this.selectedClients.add(client)
    this.doLayout()
    this.focusWindow(client.window)

proc removeWindowFromTagTable(this: WindowManager, window: TWindow) =
  for (tag, clients) in this.tagTable.mpairs():
    let clientIndex = clients.find(window)
    if clientIndex >= 0:
      let client = clients[clientIndex]
      clients.delete(clientIndex)
      # If the previouslySelectedClient is destroyed, select the first window (or none).
      if tag.previouslySelectedClient.isSome and client == tag.previouslySelectedClient.get:
        tag.previouslySelectedClient = if clients.len == 0: none(Client) else: clients[0].option

      # Set currently selected window as previouslySelectedClient
      tag.selectedClient = tag.previouslySelectedClient

  this.doLayout()

  # Focus the proper window
  if this.selectedClients.len > 0 and this.selectedTag.selectedClient.isSome:
      this.focusWindow(this.selectedTag.selectedClient.get.window)
  else:
    # If the last window in a tag was deleted, select the root window.
    discard XSetInputFocus(
      this.display,
      this.rootWindow,
      RevertToPointerRoot,
      CurrentTime
    )

proc doLayout(this: WindowManager) =
  ## Revalidates the current layout of the viewed tag(s).
  this.selectedTag.layout.arrange(
    this.display,
    this.selectedClients
  )

proc openDisplay(): PDisplay =
  let tempDisplay = XOpenDisplay(nil)
  if tempDisplay == nil:
    quit "Failed to open display"
  return tempDisplay

proc configureRootWindow(this: WindowManager): TWindow =
  result = DefaultRootWindow(this.display)
  let supported = XInternAtom(this.display, "_NET_SUPPORTED", false)
  let dataType = XInternAtom(this.display, "ATOM", false)
  var atomsNames = [
    XInternAtom(this.display, "_NET_WM_STATE", false),
    XInternAtom(this.display, "_NET_WM_STATE_FULLSCREEN", false)
  ]
  discard XChangeProperty(
    this.display,
    result,
    supported,
    dataType,
    32,
    PropModeReplace,
    cast[Pcuchar](addr(atomsNames)),
    cint(len(atomsNames))
  )

  var windowAttribs: TXSetWindowAttributes
  # Listen for events defined by eventMask.
  # See https://tronche.com/gui/x/xlib/events/processing-overview.html#SubstructureRedirectMask
  windowAttribs.event_mask = SubstructureRedirectMask # TODO: Try out awesomewm masks

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
          this.selectedTag.selectedClient.get(),
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
  for keyCombo in config.ConfigTable.keys():
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

  # Windows not on the current tag need to be hidden or unmapped.
  for client in this.selectedClients:
    discard XUnmapWindow(this.display, client.window)

  this.selectedTag = tag

  for client in this.selectedClients:
    discard XMapWindow(this.display, client.window)

  this.doLayout()

  # Select the "selected" client for the newly viewed tag
  if this.selectedTag.selectedClient.isSome:
    this.focusWindow(this.selectedTag.selectedClient.get().window)

proc keycodeToTag(this: WindowManager, keycode: int): Tag =
  try:
    let tagNumber = parseInt(keycode.toString(this.display))
    if tagNumber < 0:
      raise newException(Exception, "Tag number cannot be negative")

    var i = tagNumber
    for tag in this.tagTable.keys():
      i -= 1
      if i == 0:
        return tag
  except:
    echo "Invalid tag number from config:"
    echo getCurrentExceptionMsg()

proc focusPreviousClient(this: WindowManager) =
  if this.selectedClients.len <= 1 or
    this.selectedTag.selectedClient.isNone:
    return

  let selected = this.selectedTag.selectedClient.get()
  var previous = this.selectedTag.selectedClient.get()
  for i, client in this.selectedClients:
    if client == selected:
      if i == 0:
        # If focusing the first client, select the last client in the tag.
        let lastClient = this.selectedClients[^1]
        this.focusWindow(lastClient.window)
      else:
        this.focusWindow(previous.window)
      return
    previous = client

proc focusNextClient(this: WindowManager) =
  if this.selectedTag.selectedClient.isNone:
    return

  var isNext = false
  for client in this.selectedClients:
    if isNext:
      this.focusWindow(client.window)
      return
    if client == this.selectedTag.selectedClient.get():
      isNext = true
  
  if isNext:
    for client in this.selectedClients:
      this.focusWindow(client.window)
      return

proc moveClientPrevious(this: WindowManager) =
  let clientOption = this.selectedTag.selectedClient
  if clientOption.isNone:
    return

  var clients = this.selectedClients
  if clients.len < 2:
    return

  let selectedClient = clientOption.get()
  let selectedClientIndex = clients.find(selectedClient)
  if selectedClientIndex < 0:
    return

  var swapIndex: int = (selectedClientIndex - 1) mod clients.len
  if swapIndex == -1:
    swapIndex = clients.len - 1
  let swapClient = this.selectedClients[swapIndex]

  this.selectedClients[selectedClientIndex] = swapClient
  this.selectedClients[swapIndex] = selectedClient

  this.doLayout()

proc moveClientNext(this: WindowManager) =
  let clientOption = this.selectedTag.selectedClient
  if clientOption.isNone:
    return

  if this.selectedClients.len < 2:
    return

  let selectedClient = clientOption.get()
  let selectedClientIndex = this.selectedClients.find(selectedClient)
  if selectedClientIndex < 0:
    return

  let swapIndex = (selectedClientIndex + 1) mod this.selectedClients.len
  let swapClient = this.selectedClients[swapIndex]
  this.selectedClients[selectedClientIndex] = swapClient
  this.selectedClients[swapIndex] = selectedClient
  this.doLayout()

proc moveClientToTag(this: WindowManager, client: Client, destinationTag: Tag) =
  for tag, clients in this.tagTable.mpairs():
    if tag == destinationTag:
      if not clients.contains(client):
        clients.add(client)
        tag.setSelectedClient(client)
        discard XUnmapWindow(this.display, client.window)
    else:
      let clientIndex = clients.find(client)
      if clientIndex >= 0:
        clients.delete(clientIndex)
        if tag.previouslySelectedClient.isSome():
          tag.setSelectedClient(tag.previouslySelectedClient.get())
          # Ensure our current tag has a window selected if one exists.
          if tag == this.selectedTag:
            if this.selectedTag.selectedClient.isSome():
              this.focusWindow(this.selectedTag.selectedClient.get().window)
              this.doLayout()

proc destroySelectedWindow(this: WindowManager) =
  var selectedWin: TWindow
  var selectionState: cint
  discard XGetInputFocus(this.display, addr(selectedWin), addr(selectionState))
  var event = TXEvent()
  event.xclient.theType = ClientMessage
  event.xclient.window = selectedWin
  event.xclient.message_type = XInternAtom(this.display, "WM_PROTOCOLS", true)
  event.xclient.format = 32
  event.xclient.data.l[0] = XInternAtom(this.display, "WM_DELETE_WINDOW", false).cint
  event.xclient.data.l[1] = CurrentTime
  discard XSendEvent(this.display, selectedWin, false, NoEventMask, addr(event))
  discard XDestroyWindow(this.display, selectedWin)

#####################
## XEvent Handling ##
#####################

proc getNetAtom(this: WindowManager, id: NetAtom): TAtom =
  this.netAtoms[ord(id)]

proc errorHandler(display: PDisplay, error: PXErrorEvent): cint{.cdecl.} =
  echo repr(error.resourceid)
  var errorMessage: string = newString(1024)
  discard XGetErrorText(
    display,
    cint(error.error_code),
    errorMessage.cstring,
    len(errorMessage)
  )
  # Reduce string length down to the proper size
  errorMessage.setLen(errorMessage.cstring.len)
  echo errorMessage

proc toggleFullscreen(this: WindowManager, client: var Client) =
  if client.isFullscreen:
    discard XChangeProperty(
      this.display,
      client.window,
      this.getNetAtom(NetWMState),
      XA_ATOM,
      32,
      PropModeReplace,
      cast[Pcuchar]([]),
      0
    )
    this.addClientToSelectedTags(client.window)

    # Ensure the window has focus
    this.focusWindow(client.window)
    discard XChangeProperty(
      this.display,
      this.rootWindow,
      this.getNetAtom(NetActiveWindow),
      XA_WINDOW,
      32,
      PropModeReplace,
      cast[Pcuchar](unsafeAddr(client.window)),
      1
    )
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
    var arr = [this.getNetAtom(NetWMFullScreen)]   
    discard XChangeProperty(
      this.display,
      client.window,
      this.getNetAtom(NetWMState),
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
  if this.isInTagTable(e.window):
    var changes: TXWindowChanges
    changes.x = e.x
    changes.y = e.y
    changes.width = e.width
    changes.height = e.height
    changes.border_width = e.border_width
    changes.sibling = e.above;
    changes.stack_mode = e.detail;
    discard XConfigureWindow(this.display, e.window, cuint(e.value_mask), addr(changes));
    discard XSync(this.display, false)

proc onClientMessage(this: WindowManager, e: TXClientMessageEvent) =
  var clientIndex = this.selectedClients.find(e.window)
  if clientIndex < 0:
    return

  if e.message_type == this.getNetAtom(NetWMState):
    let fullscreenAtom = this.getNetAtom(NetWMFullScreen)
    if e.data.l[1] == fullscreenAtom or
      e.data.l[2] == fullscreenAtom:
        var client = this.selectedClients[clientIndex]
        this.toggleFullscreen(client)

proc onMapRequest(this: WindowManager, e: TXMapRequestEvent) =
  var windowAttr: TXWindowAttributes
  if XGetWindowAttributes(this.display, e.window, addr(windowAttr)) == 0:
    return
  if windowAttr.override_redirect:
    return

  if not this.isInTagTable(e.window):
    discard XSetWindowBorderWidth(this.display, e.window, borderWidth)
    discard XSetWindowBorder(this.display, e.window, borderColorUnfocused)
    discard XSelectInput(
      this.display,
      e.window,
      StructureNotifyMask or
      PropertyChangeMask or
      ResizeRedirectMask or
      EnterWindowMask or
      FocusChangeMask
    )
    discard XMapWindow(this.display, e.window)

proc onEnterNotify(this: WindowManager, e: TXCrossingEvent) =
  if e.window != this.rootWindow:
    discard XSetInputFocus(this.display, e.window, RevertToPointerRoot, CurrentTime)

proc onFocusIn(this: WindowManager, e: TXFocusChangeEvent) =
  if e.detail == NotifyPointer or
    e.window == this.rootWindow:
    return

  let clientIndex = this.selectedClients.find(e.window)
  if clientIndex >= 0:
    let client = this.selectedClients[clientIndex]
    this.selectedTag.setSelectedClient(client)
    discard XSetWindowBorder(
      this.display,
      client.window,
      borderColorFocused
    )
    if this.selectedTag.previouslySelectedClient.isSome:
      let previous = this.selectedTag.previouslySelectedClient.get()
      if previous.window != client.window:
        discard XSetWindowBorder(
          this.display,
          previous.window,
          borderColorUnfocused
        )

