import
  sugar,
  options,
  tables,
  strutils,
  x11 / [x, xlib, xutil, xatom],
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

const wmName = "nimdow"

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
    abnormalWindowTypes: array[9, TAtom]

proc initListeners(this: WindowManager)
proc openDisplay(): PDisplay
proc configureConfigActions*(this: WindowManager)
proc configureRootWindow(this: WindowManager): TWindow
proc configureWindowMappingListeners(this: WindowManager, eventManager: XEventManager)
proc getNetAtom(this: WindowManager, id: NetAtom): TAtom
proc addClientToAllTags(this: WindowManager, client: Client)
proc removeWindowFromTagTable(this: WindowManager, window: TWindow)
proc findClient(this: WindowManager, window: TWindow): Option[Client]
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
proc onPropertyNotify(this: WindowManager, e: TXPropertyEvent)
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
          borderWidth = borderWidth,
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
  discard XChangeProperty(result.display,
                          wmcheckwin,
                          result.netAtoms[ord(NetWMCheck)],
                          XA_WINDOW,
                          32,
                          PropModeReplace,
                          cast[Pcuchar](wmcheckwin.unsafeAddr),
                          1)

  discard XChangeProperty(result.display,
                          wmcheckwin,
                          result.netAtoms[ord(NetWMName)],
                          utf8string,
                          8,
                          PropModeReplace,
                          cast[Pcuchar](wmName),
                          len(wmName))

  discard XChangeProperty(result.display,
                          result.rootWindow,
                          result.netAtoms[ord(NetWMCheck)],
                          XA_WINDOW,
                          32,
                          PropModeReplace,
                          cast[Pcuchar](wmcheckwin.unsafeAddr),
                          1)
  # EWMH support per view
  discard XChangeProperty(result.display,
                          result.rootWindow,
                          result.netAtoms[ord(NetSupported)],
                          XA_ATOM,
                          32,
                          PropModeReplace,
                          cast[Pcuchar](result.netAtoms.unsafeAddr),
                          ord(NetLast))

  discard XDeleteProperty(result.display, result.rootWindow, result.netAtoms[ord(NetClientList)]);

  result.abnormalWindowTypes[0] = result.getNetAtom(NetWMWindowTypeDialog)
  result.abnormalWindowTypes[1] = result.getNetAtom(NetWMWindowTypeUtility)
  result.abnormalWindowTypes[2] = result.getNetAtom(NetWMWindowTypeToolbar)
  result.abnormalWindowTypes[3] = result.getNetAtom(NetWMWindowTypeSplash)
  result.abnormalWindowTypes[4] = result.getNetAtom(NetWMWindowTypeMenu)
  result.abnormalWindowTypes[5] = result.getNetAtom(NetWMWindowTypeDropdownMenu)
  result.abnormalWindowTypes[6] = result.getNetAtom(NetWMWindowTypePopupMenu)
  result.abnormalWindowTypes[6] = result.getNetAtom(NetWMWindowTypeTooltip)
  result.abnormalWindowTypes[7] = result.getNetAtom(NetWMWindowTypeNotification)
  result.abnormalWindowTypes[8] = result.getNetAtom(NetWMWindowTypeDock)

template currTagClients(this: WindowManager): untyped =
  ## Grabs the windows on the current tag.
  ## This is used like an alias, e.g.:
  ## `let clients = this.tagTable[this.selectedTags]`
  ## `clients` would be a copy of the collection.
  this.tagTable[this.selectedTag]

proc initListeners(this: WindowManager) =
  discard XSetErrorHandler(errorHandler)
  this.eventManager.addListener((e: TXEvent) => onConfigureRequest(this, e.xconfigurerequest), ConfigureRequest)
  this.eventManager.addListener((e: TXEvent) => onPropertyNotify(this, e.xproperty), PropertyNotify)
  this.eventManager.addListener((e: TXEvent) => onClientMessage(this, e.xclient), ClientMessage)
  this.eventManager.addListener((e: TXEvent) => onMapRequest(this, e.xmaprequest), MapRequest)
  this.eventManager.addListener((e: TXEvent) => onEnterNotify(this, e.xcrossing), EnterNotify)
  this.eventManager.addListener((e: TXEvent) => onFocusIn(this, e.xfocus), FocusIn)

proc configureWindowMappingListeners(this: WindowManager, eventManager: XEventManager) =
  eventManager.addListener(
    proc (e: TXEvent) =
      removeWindowFromTagTable(this, e.xdestroywindow.window), DestroyNotify)

proc focusWindow(this: WindowManager, window: TWindow) =
  discard XSetInputFocus(this.display, window, RevertToPointerRoot, CurrentTime)

proc addClientToAllTags(this: WindowManager, client: Client) =
  for tag in this.tagTable.keys():
    if not this.tagTable[tag].contains(client):
      this.tagTable[tag].add(client)
  this.doLayout()

proc removeWindowFromTagTable(this: WindowManager, window: TWindow) =
  for (tag, clients) in this.tagTable.mpairs():
    let clientIndex = clients.find(window)
    if clientIndex >= 0:
      let client = clients[clientIndex]
      clients.delete(clientIndex)
      # If the previouslySelectedClient is destroyed, select the first window (or none).
      if tag.previouslySelectedClient.isSome and client == tag.previouslySelectedClient.get:
        if clients.len == 0:
          tag.previouslySelectedClient = none(Client)
        else:
          # Find and assign the next normal client as "previouslySelectedClient"
          let nextNormalIndex = clients.findNextNormal(0)
          if nextNormalIndex >= 0:
            tag.previouslySelectedClient = clients[nextNormalIndex].option

      # Set currently selected window as previouslySelectedClient
      tag.selectedClient = tag.previouslySelectedClient

  this.doLayout()

  # Focus the proper window
  if this.currTagClients.len > 0 and this.selectedTag.selectedClient.isSome:
      this.focusWindow(this.selectedTag.selectedClient.get.window)
  else:
    # If the last window in a tag was deleted, select the root window.
    discard XSetInputFocus(
      this.display,
      this.rootWindow,
      RevertToPointerRoot,
      CurrentTime
    )

proc findClient(this: WindowManager, window: TWindow): Option[Client] =
  for tag, clients in this.tagTable.pairs():
    let clientIndex = clients.find(window)
    if clientIndex >= 0:
      return clients[clientIndex].option
  return none(Client)

proc doLayout(this: WindowManager) =
  ## Revalidates the current layout of the viewed tag(s).
  this.selectedTag.layout.arrange(
    this.display,
    this.currTagClients
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
  for client in this.currTagClients:
    discard XUnmapWindow(this.display, client.window)

  this.selectedTag = tag

  for client in this.currTagClients:
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

proc moveClientToTag(this: WindowManager, client: Client, destinationTag: Tag) =
  for tag, clients in this.tagTable.mpairs():
    if tag == destinationTag:
      if not clients.contains(client):
        clients.add(client)
        tag.setSelectedClient(client)
        discard XUnmapWindow(this.display, client.window)
    else:
      let clientIndex = clients.find(client)
      if clientIndex < 0:
        continue
      clients.delete(clientIndex)
      tag.clearSelectedClient(client)
      if tag.previouslySelectedClient.isNone():
        continue
      tag.setSelectedClient(tag.previouslySelectedClient.get())
      # Ensure our current tag has a window selected if one exists.
      if tag == this.selectedTag and this.selectedTag.selectedClient.isSome():
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

proc getWMAtom(this: WindowManager, id: WMAtom): TAtom =
  this.wmAtoms[ord(id)]

proc getXAtom(this: WindowManager, id: XAtom): TAtom =
  this.xAtoms[ord(id)]

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
      this.getNetAtom(NetWMState),
      XA_ATOM,
      32,
      PropModeReplace,
      cast[Pcuchar]([]),
      0
    )
    #this.addClientToSelectedTags(client)

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

template copyMaskMember(
  event: TXConfigureRequestEvent,
  changeMember: untyped,
  mask: int,
  maskMember: int,
  eventMember: untyped
) =
  if (event.value_mask and maskMember) != 0:
    mask = mask or maskMember
    changeMember = event.eventMember

proc onConfigureRequest(this: WindowManager, e: TXConfigureRequestEvent) =
  var mask: int
  var changes: TXWindowChanges
  copyMaskMember(e, changes.x, mask, 0, x)
  copyMaskMember(e, changes.y, mask, 1, y)
  copyMaskMember(e, changes.width, mask, 2, width)
  copyMaskMember(e, changes.height, mask, 3, height)
  copyMaskMember(e, changes.border_width, mask, 4, border_width)
  copyMaskMember(e, changes.sibling, mask, 5, above)
  copyMaskMember(e, changes.stack_mode, mask, 6, detail)

  discard XConfigureWindow(this.display, e.window, cuint(mask), addr(changes));
  discard XSync(this.display, false)

  discard XMoveResizeWindow(
    this.display,
    e.window,
    changes.x,
    changes.y,
    changes.width,
    changes.height
  )

proc onPropertyNotify(this: WindowManager, e: TXPropertyEvent) =
  if e.state == PropertyDelete:
    return
  
  # TODO:
  # Getting a WM_STATE event about Gimp's splash window.
  # It must indicate the window is being destroyed,
  # and we need to remove it from tags if it is.
  echo "PropertyNotify: "
  case e.atom:
    of XA_WM_TRANSIENT_FOR:
      echo "transient!"
    of XA_WM_NORMAL_HINTS:
      echo "Need to update size hints"
    of XA_WM_HINTS:
      echo "Normal hints"
    else:
      if e.atom != None:
        echo XGetAtomName(this.display, e.atom)

  if e.atom == this.getNetAtom(NetWMWindowType):
      echo "Need to update window type!"
  
proc onClientMessage(this: WindowManager, e: TXClientMessageEvent) =
  var clientIndex = this.currTagClients.find(e.window)
  if clientIndex < 0:
    return

  if e.message_type == this.getNetAtom(NetWMState):
    let fullscreenAtom = this.getNetAtom(NetWMFullScreen)
    if e.data.l[1] == fullscreenAtom or
      e.data.l[2] == fullscreenAtom:
        var client = this.currTagClients[clientIndex]
        this.toggleFullscreen(client)

proc getAtomProperty(this: WindowManager, window: TWindow, property: TAtom): TAtom =
  var
    actualTypeReturn: TAtom
    actualFormatReturn: cint
    numItemsReturn: culong
    bytesAfterReturn: culong
    propReturn: ptr array[2, cint]

  let getPropResult = XGetWindowProperty(
    this.display,
    window,
    property,
    0,
    sizeof(TAtom) div 4,
    false,
    AnyPropertyType,
    actualTypeReturn.addr,
    actualFormatReturn.addr,
    numItemsReturn.addr,
    bytesAfterReturn.addr,
    cast[PPcuchar](propReturn.addr)
  )
  if getPropResult == Success and propReturn != nil:
    return TAtom(propReturn[0])
  if actualTypeReturn == this.getXAtom(XembedInfo) and numItemsReturn == 2:
    return TAtom(propReturn[1])
  return None

proc updateWindowType(this: WindowManager, client: var Client) =
  let
    state = this.getAtomProperty(client.window, this.getNetAtom(NetWMState))
    windowType = this.getAtomProperty(client.window, this.getNetAtom(NetWMWindowType))

  echo "\nWindow: ", client.window
  echo "\tState: ", state
  echo "\t\t", if windowType == None: "0" else: $XGetAtomName(this.display, windowType)
  echo "\twindowType: ", windowType

  if state == this.getNetAtom(NetWMFullScreen) and not client.isFullscreen:
    this.toggleFullscreen(client)

  if client.isNormal and
    windowType != None and
    windowType != this.getNetAtom(NetWMWindowTypeNormal) and
    windowType != this.getNetAtom(NetWMWindowType):
    client.isFloating = true
    # Docks should be added to every tag.
    if windowType == this.getNetAtom(NetWMWindowTypeDock):
      this.addClientToAllTags(client)

proc manage(this: WindowManager, window: TWindow, windowAttr: TXWindowAttributes) =
  var
    transientWindow: TWindow
    client = newClient(window)
    windowChanges: TXWindowChanges

  block transient:
    var temp = this.findClient(window)
    # 0 is false in C, everything else is true.
    if not XGetTransientForHint(this.display, window, addr(transientWindow)) == 0 and temp.isSome:
      client.isFloating = temp.get.isFloating

  windowChanges.border_width = client.borderWidth
  discard XConfigureWindow(this.display, window, CWBorderWidth, addr(windowChanges))
  discard XSetWindowBorder(this.display, window, borderColorUnfocused)

  this.updateWindowType(client)
  
  discard XSelectInput(this.display,
                       window,
                       StructureNotifyMask or
                       PropertyChangeMask or
                       # TODO: ResizeRedirectMask not needed?
                       ResizeRedirectMask or
                       EnterWindowMask or
                       FocusChangeMask
                      )
  # TODO: Revise
  if client.isNormal:
    client.isFloating = transientWindow != None

  if not client.isNormal:
    discard XRaiseWindow(this.display, client.window)

  discard XChangeProperty(this.display,
                         this.rootWindow,
                         this.getNetAtom(NetClientList),
                         XA_WINDOW,
                         32,
                         PropModeAppend,
                         cast[Pcuchar](client.window.unsafeAddr),
                         1)

  discard XMoveResizeWindow(this.display,
                            client.window,
                            windowAttr.x,
                            windowAttr.y,
                            windowAttr.width,
                            windowAttr.height)

  let data: array[2, int] = [ NormalState, None ]
  discard XChangeProperty(this.display,
                          client.window,
                          this.getWMAtom(WMState),
                          this.getWMAtom(WMState),
                          32,
                          PropModeReplace,
                          cast[Pcuchar](data.unsafeAddr),
                          data.len)

  this.currTagClients.add(client)
  discard XMapWindow(this.display, client.window)
  this.doLayout()

proc onMapRequest(this: WindowManager, e: TXMapRequestEvent) =
  var windowAttr: TXWindowAttributes
  # TODO: Error thrown here for gimp splash screen (BadValue)
  if XGetWindowAttributes(this.display, e.window, addr(windowAttr)) == 0:
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
  
  let client = this.currTagClients[clientIndex]
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

