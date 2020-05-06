import
  sugar,
  options,
  tables,
  sets,
  x11 / [x, xlib],
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
    tagTable: OrderedTable[Tag, OrderedSet[TWindow]]
    selectedTag: Tag
    atoms: array[3, TAtom]

proc initListeners(this: WindowManager)
proc openDisplay(): PDisplay
proc configureConfigActions*(this: WindowManager)
proc configureRootWindow(this: WindowManager): TWindow
proc configureWindowMappingListeners(this: WindowManager, eventManager: XEventManager)
proc firstItem[T](s: OrderedSet[T]): T
proc addWindowToSelectedTags(this: WindowManager, window: TWindow)
proc removeWindowFromTagTable(this: WindowManager, window: TWindow)
proc doLayout(this: WindowManager)
# Custom WM actions
proc testAction*(this: WindowManager)
proc destroySelectedWindow(this: WindowManager)
# XEvents
proc hookConfigKeys*(this: WindowManager)
proc errorHandler(disp: PDisplay, error: PXErrorEvent): cint{.cdecl.}
proc onClientMessage(this: WindowManager, e: TXClientMessageEvent)
proc onCreateNotify(this: WindowManager, e: TXCreateWindowEvent)
proc onMapRequest(this: WindowManager, e: TXMapRequestEvent)
proc onEnterNotify(this: WindowManager, e: TXCrossingEvent)
proc onFocusIn(this: WindowManager, e: TXFocusChangeEvent)
proc onFocusOut(this: WindowManager, e: TXFocusChangeEvent)

proc newWindowManager*(eventManager: XEventManager): WindowManager =
  result = WindowManager()
  result.display = openDisplay()
  result.rootWindow = result.configureRootWindow()
  result.eventManager = eventManager
  result.atoms = xatoms.createXAtoms(result.display)
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

proc initListeners(this: WindowManager) =
  ## Hooks into various XEvents
  discard XSetErrorHandler(errorHandler)
  this.eventManager.addListener((e: TXEvent) => onClientMessage(this, e.xclient), ClientMessage)
  this.eventManager.addListener((e: TXEvent) => onCreateNotify(this, e.xcreatewindow), CreateNotify)
  this.eventManager.addListener((e: TXEvent) => onMapRequest(this, e.xmaprequest), MapRequest)
  this.eventManager.addListener((e: TXEvent) => onEnterNotify(this, e.xcrossing), EnterNotify)
  this.eventManager.addListener((e: TXEvent) => onFocusIn(this, e.xfocus), FocusIn)
  this.eventManager.addListener((e: TXEvent) => onFocusOut(this, e.xfocus), FocusOut)

proc configureWindowMappingListeners(this: WindowManager, eventManager: XEventManager) =
  eventManager.addListener(
    proc(e: TXEvent) =
      if e.xmap.override_redirect:
        return
      addWindowToSelectedTags(this, e.xmap.window),
    MapNotify
  )
  eventManager.addListener(
    proc (e: TXEvent) = removeWindowFromTagTable(this, e.xunmap.window), UnmapNotify)
  eventManager.addListener(
    proc (e: TXEvent) = removeWindowFromTagTable(this, e.xdestroywindow.window), DestroyNotify)

proc firstItem[T](s: OrderedSet[T]): T =
  for item in s:
    return item

proc addWindowToSelectedTags(this: WindowManager, window: TWindow) =
  #if e.override_redirect:
    #return

  this.tagTable[this.selectedTag].incl(window)
  this.doLayout()
  discard XSetInputFocus(this.display, window, RevertToNone, CurrentTime)
  this.selectedTag.setSelectedWindow(window)

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
      discard XSetInputFocus(
        this.display,
        this.selectedTag.selectedWin.get,
        RevertToNone,
        CurrentTime
      )
    else:
      # If the last window in a tag was deleted, select the root window.
      discard XSetInputFocus(
        this.display,
        this.rootWindow,
        RevertToNone,
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
  var windowAttribs: TXSetWindowAttributes
  # Listen for events defined by eventMask.
  # See https://tronche.com/gui/x/xlib/events/processing-overview.html#SubstructureRedirectMask
  # Events bubble up the hierarchy to the root window.
  windowAttribs.eventMask =
    SubstructureRedirectMask or
    SubstructureNotifyMask or
    ButtonPressMask or
    PointerMotionMask or
    StructureNotifyMask or
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
  config.configureAction("testAction", () => testAction(this))
  config.configureAction("destroySelectedWindow", () => destroySelectedWindow(this))

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
  var selectedWin: TWindow
  var selectionState: cint
  discard XGetInputFocus(this.display, addr(selectedWin), addr(selectionState))
  echo "Selected win: ", selectedWin
  echo "Selection state: ", selectionState

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

proc getAtom(this: WindowManager, id: XAtomID): TAtom =
  this.atoms[ord(id)]

proc errorHandler(disp: PDisplay, error: PXErrorEvent): cint{.cdecl.} =
  echo "Error: ", error.theType

proc toggleFullscreen(this: WindowManager, window: TWindow) =
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
  else:
    this.addWindowToSelectedTags(window)

  # Ensure the window has focus
  discard XSetInputFocus(this.display, window, RevertToNone, CurrentTime)

proc onClientMessage(this: WindowManager, e: TXClientMessageEvent) =
  if e.message_type == this.getAtom(NetWMState):
    # 267 from firefox?
    let fullscreenAtom = this.getAtom(NetWMFullScreen)
    if e.data.l[1] == fullscreenAtom or
      e.data.l[2] == fullscreenAtom:
        this.toggleFullscreen(e.window)

proc onCreateNotify(this: WindowManager, e: TXCreateWindowEvent) =
  if e.override_redirect:
    # Advised by xlib docs to ignore windows when this attribute is true
    return

  discard XSetWindowBorderWidth(this.display, e.window, borderWidth)
  discard XSetWindowBorder(this.display, e.window, borderColorUnfocused)
  discard XSelectInput(
    this.display,
    e.window,
    SubstructureRedirectMask or
    SubstructureNotifyMask or
    EnterWindowMask or
    FocusChangeMask
  )

proc onMapRequest(this: WindowManager, e: TXMapRequestEvent) =
  discard XMapWindow(this.display, e.window)

proc onEnterNotify(this: WindowManager, e: TXCrossingEvent) =
  discard XSetInputFocus(this.display, e.window, RevertToNone, CurrentTime)

proc onFocusIn(this: WindowManager, e: TXFocusChangeEvent) =
  discard XSetWindowBorder(this.display, e.window, borderColorFocused)
  this.selectedTag.setSelectedWindow(e.window)

proc onFocusOut(this: WindowManager, e: TXFocusChangeEvent) =
  discard XSetWindowBorder(this.display, e.window, borderColorUnfocused)

