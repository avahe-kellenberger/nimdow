import
  sugar,
  options,
  tables,
  sets,
  x11 / [x, xlib, xatom],
  xatoms,
  tag,
  config/config,
  event/xeventmanager,
  layouts/layout,
  layouts/masterstacklayout

converter intToCint(x: int): cint = x.cint
converter intToCUint(x: int): cuint = x.cuint
converter cintToCUint(x: cint): cuint = x.cuint
converter clongToCUlong(x: clong): culong = x.culong
converter toTBool(x: bool): TBool = x.TBool
converter toBool(x: TBool): bool = x.bool

# TODO: Should load these from settings
const borderColorFocused = 0x3355BB
const borderColorUnfocused = 0x335544
const borderWidth = 2

type
  WindowManager* = ref object
    display*: PDisplay
    rootWindow*: TWindow
    eventManager: XEventManager
    # Tags
    tagTable: OrderedTable[Tag, OrderedSet[TWindow]]
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
proc firstItem[T](s: OrderedSet[T]): T
proc isInTagTable(this: WindowManager, window: TWindow): bool
proc addWindowToSelectedTags(this: WindowManager, window: TWindow)
proc removeWindowFromTagTable(this: WindowManager, window: TWindow)
proc doLayout(this: WindowManager)
# Custom WM actions
proc testAction*(this: WindowManager)
proc toggleFullscreen(this: WindowManager, window: TWindow)
proc destroySelectedWindow(this: WindowManager)
# XEvents
proc hookConfigKeys*(this: WindowManager)
proc errorHandler(display: PDisplay, error: PXErrorEvent): cint{.cdecl.}
proc onConfigureRequest(this: WindowManager, e: TXConfigureRequestEvent)
proc onClientMessage(this: WindowManager, e: TXClientMessageEvent)
proc onMapRequest(this: WindowManager, e: TXMapRequestEvent)
proc onEnterNotify(this: WindowManager, e: TXCrossingEvent)
proc onFocusIn(this: WindowManager, e: TXFocusChangeEvent)
proc onFocusOut(this: WindowManager, e: TXFocusChangeEvent)

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
    result.tagTable = OrderedTable[Tag, OrderedSet[TWindow]]()
    for i in 1..9:
      let tag: Tag = newTag(
        id = i,
        layout = newMasterStackLayout(
          gapSize = 48,
          borderSize = 2,
          masterSlots = 1
        )
      )
      result.tagTable[tag] = initOrderedSet[TWindow]()
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

proc initListeners(this: WindowManager) =
  discard XSetErrorHandler(errorHandler)
  this.eventManager.addListener((e: TXEvent) => onConfigureRequest(this, e.xconfigurerequest), ConfigureRequest)
  this.eventManager.addListener((e: TXEvent) => onClientMessage(this, e.xclient), ClientMessage)
  this.eventManager.addListener((e: TXEvent) => onMapRequest(this, e.xmaprequest), MapRequest)
  this.eventManager.addListener((e: TXEvent) => onEnterNotify(this, e.xcrossing), EnterNotify)
  this.eventManager.addListener((e: TXEvent) => onFocusIn(this, e.xfocus), FocusIn)
  this.eventManager.addListener((e: TXEvent) => onFocusOut(this, e.xfocus), FocusOut)

proc configureWindowMappingListeners(this: WindowManager, eventManager: XEventManager) =
  eventManager.addListener(
    proc(e: TXEvent) =
      if not e.xmap.override_redirect:
        addWindowToSelectedTags(this, e.xmap.window),
    MapNotify
  )
  eventManager.addListener(
    proc (e: TXEvent) =
      removeWindowFromTagTable(this, e.xunmap.window), UnmapNotify)
  eventManager.addListener(
    proc (e: TXEvent) =
      removeWindowFromTagTable(this, e.xdestroywindow.window), DestroyNotify)

proc firstItem[T](s: OrderedSet[T]): T =
  for item in s:
    return item

proc focusWindow(this: WindowManager, window: TWindow) =
  discard XSetInputFocus(this.display, window, RevertToPointerRoot, CurrentTime)
  this.selectedTag.setSelectedWindow(window)

proc isInTagTable(this: WindowManager, window: TWindow): bool =
  for windows in this.tagTable.values():
    if window in windows:
      return true
  return false

proc addWindowToSelectedTags(this: WindowManager, window: TWindow) =
  this.tagTable[this.selectedTag].incl(window)
  this.doLayout()
  this.focusWindow(window)

proc removeWindowFromTagTable(this: WindowManager, window: TWindow) =
  let numWindowsInSelectedTag = this.tagTable[this.selectedTag].len
  for (tag, windows) in this.tagTable.mpairs():
    windows.excl(window)

    # If removed window is same as previouslySelectedWin, assign it to the first window on the tag.
    if not tag.previouslySelectedWin.isNone and window == tag.previouslySelectedWin.get:
      tag.previouslySelectedWin = firstItem(windows).option
    # Set currently selected window as previouslySelectedWin
    tag.selectedWin = tag.previouslySelectedWin

  # Check if the number of windows on the current tag has changed
  if numWindowsInSelectedTag != this.tagTable[this.selectedTag].len:
    this.doLayout()
    if this.tagTable[this.selectedTag].len > 0:
      this.focusWindow(this.selectedTag.selectedWin.get)
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
  this.selectedTag.layout.doLayout(
    this.display,
    this.tagTable[this.selectedTag]
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
  var atomsNames: array[2, TAtom]
  atomsNames[0] = XInternAtom(this.display, "_NET_WM_STATE", false)
  atomsNames[1] = XInternAtom(this.display, "_NET_WM_STATE_FULLSCREEN", false)

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
  # Events bubble up the hierarchy to the root window.
  windowAttribs.event_mask =
    StructureNotifyMask or
    SubstructureRedirectMask or
    SubstructureNotifyMask or
    ButtonPressMask or
    PointerMotionMask or
    EnterWindowMask or
    LeaveWindowMask or
    PropertyChangeMask or
    KeyPressMask or
    KeyReleaseMask

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
  config.configureAction("testAction", () => this.testAction())
  config.configureAction("toggleFullscreen",
   proc() =
     if this.selectedTag.selectedWin.isSome:
       this.toggleFullscreen(this.selectedTag.selectedWin.get)
     )
  config.configureAction("destroySelectedWindow", () => this.destroySelectedWindow())

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

proc testAction(this: WindowManager) =
  echo "Num windows: ", this.tagTable[this.selectedTag].len

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
  var errorMessage: string = newString(1024)
  discard XGetErrorText(
    display,
    cint(error.error_code),
    errorMessage.cstring,
    len(errorMessage)
  )
  # Reduce string length down to the proper size
  errorMessage.setLen(errorMessage.cstring.len)
  echo "\t", errorMessage, "\n"

proc toggleFullscreen(this: WindowManager, window: TWindow) =
  if window == this.rootWindow:
    return
  if window in this.tagTable[this.selectedTag]:
    this.removeWindowFromTagTable(window)
    discard XSetWindowBorderWidth(this.display, window, 0)
    discard XMoveResizeWindow(
      this.display,
      window,
      0,
      0,
      XDisplayWidth(this.display, 0),
      XDisplayHeight(this.display, 0),
    )

    var arr = [this.getNetAtom(NetWMFullScreen)]   
    discard XChangeProperty(
      this.display,
      window,
      this.getNetAtom(NetWMState),
      XA_ATOM,
      32,
      PropModeReplace,
      cast[Pcuchar](arr.addr),
      1
    )
    discard XRaiseWindow(this.display, window)
  else:
    discard XChangeProperty(
      this.display,
      window,
      this.getNetAtom(NetWMState),
      XA_ATOM,
      32,
      PropModeReplace,
      cast[Pcuchar]([]),
      0
    )
    this.addWindowToSelectedTags(window)

  # Ensure the window has focus
  discard XSetInputFocus(this.display, window, RevertToPointerRoot, CurrentTime)
  discard XChangeProperty(
    this.display,
    this.rootWindow,
    this.getNetAtom(NetActiveWindow),
    XA_WINDOW,
    32,
    PropModeReplace,
    cast[Pcuchar](unsafeAddr(window)),
    1
  )

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
  if e.message_type == this.getNetAtom(NetWMState):
    let fullscreenAtom = this.getNetAtom(NetWMFullScreen)
    if e.data.l[1] == fullscreenAtom or
      e.data.l[2] == fullscreenAtom:
        this.toggleFullscreen(e.window)

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
  if e.window != this.rootWindow:
    discard XSetWindowBorder(this.display, e.window, borderColorFocused)
    this.selectedTag.setSelectedWindow(e.window)

proc onFocusOut(this: WindowManager, e: TXFocusChangeEvent) =
  if e.window in this.tagTable[this.selectedTag]:
    # Ensure the window is still valid or in our currently viewed tag(s).
    # This proc could be invoked after a window is destroyed.
    discard XSetWindowBorder(this.display, e.window, borderColorUnfocused)

