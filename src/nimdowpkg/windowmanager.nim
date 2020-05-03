import
  sugar,
  tables,
  sets,
  x11 / [x, xlib],
  tag,
  config/config,
  event/xeventmanager,
  layouts/layout,
  layouts/masterstacklayout

converter intToCint(x: int): cint = x.cint
converter intToCUint(x: int): cuint = x.cuint
converter cUlongToCUint(x: culong): cuint = x.cuint
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

proc initListeners(this: WindowManager)
proc openDisplay(): PDisplay
proc configureConfigActions*(this: WindowManager)
proc configureRootWindow(this: WindowManager): TWindow
proc configureWindowMappingListeners(this: WindowManager, eventManager: XEventManager)
proc addWindowToSelectedTags(this: WindowManager, e: TXMapEvent)
proc removeWindowFromTagTable(this: WindowManager, window: TWindow)
proc doLayout(this: WindowManager)
# Custom WM actions
proc testAction*(this: WindowManager)
proc destroySelectedWindow(this: WindowManager)
# XEvents
proc hookConfigKeys*(this: WindowManager)
proc errorHandler(disp: PDisplay, error: PXErrorEvent): cint{.cdecl.}
proc onCreateNotify(this: WindowManager, e: TXCreateWindowEvent)
proc onConfigureRequest(this: WindowManager, e: TXConfigureRequestEvent)
proc onMapRequest(this: WindowManager, e: TXMapRequestEvent)
proc onEnterNotify(this: WindowManager, e: TXCrossingEvent)
proc onFocusIn(this: WindowManager, e: TXFocusChangeEvent)
proc onFocusOut(this: WindowManager, e: TXFocusChangeEvent)

proc newWindowManager*(eventManager: XEventManager): WindowManager =
  result = WindowManager()
  result.display = openDisplay()
  result.rootWindow = result.configureRootWindow()
  result.eventManager = eventManager

  result.initListeners()

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
  this.eventManager.addListener((e: TXEvent) => onCreateNotify(this, e.xcreatewindow), CreateNotify)
  this.eventManager.addListener((e: TXEvent) => onConfigureRequest(this, e.xconfigurerequest), ConfigureRequest)
  this.eventManager.addListener((e: TXEvent) => onMapRequest(this, e.xmaprequest), MapRequest)
  this.eventManager.addListener((e: TXEvent) => onEnterNotify(this, e.xcrossing), EnterNotify)
  this.eventManager.addListener((e: TXEvent) => onFocusIn(this, e.xfocus), FocusIn)
  this.eventManager.addListener((e: TXEvent) => onFocusOut(this, e.xfocus), FocusOut)

proc configureWindowMappingListeners(this: WindowManager, eventManager: XEventManager) =
  eventManager.addListener(
    (e: TXEvent) => addWindowToSelectedTags(this, e.xmap), MapNotify)
  eventManager.addListener(
    (e: TXEvent) => removeWindowFromTagTable(this, e.xunmap.window), UnmapNotify)
  eventManager.addListener(
    (e: TXEvent) => removeWindowFromTagTable(this, e.xdestroywindow.window), DestroyNotify)

proc addWindowToSelectedTags(this: WindowManager, e: TXMapEvent) =
  this.tagTable[this.selectedTag].incl(e.window)
  this.doLayout()

proc removeWindowFromTagTable(this: WindowManager, window: TWindow) =
  let numWindowsInSelectedTag = this.tagTable[this.selectedTag].len
  for windows in this.tagTable.mvalues():
    # TODO: Find previous window (same index or index - 1?) and select it.
    windows.excl(window)
  # Check if the number of windows on the current tag has changed
  if numWindowsInSelectedTag != this.tagTable[this.selectedTag].len:
    this.doLayout()

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

proc errorHandler(disp: PDisplay, error: PXErrorEvent): cint{.cdecl.} =
  echo "Error: ", error.theType

proc onCreateNotify(this: WindowManager, e: TXCreateWindowEvent) =
  discard XSetWindowBorderWidth(this.display, e.window, borderWidth)
  discard XSetWindowBorder(this.display, e.window, borderColorUnfocused)
  # TODO: We need to track these calls to populate tag info (selectedWin and previouslySelectedWin)
  discard XSelectInput(
    this.display,
    e.window,
    SubstructureRedirectMask or
    SubstructureNotifyMask or
    EnterWindowMask or
    FocusChangeMask
  )

proc onConfigureRequest(this: WindowManager, e: TXConfigureRequestEvent) =
  # Pass config defaults down (for now)
  var changes: TXWindowChanges
  changes.x = e.x
  changes.y = e.y
  changes.width = e.width
  changes.height = e.height
  changes.border_width = e.border_width
  changes.sibling = e.above
  changes.stack_mode = e.detail
  discard XConfigureWindow(this.display, e.window, e.value_mask, addr(changes))

proc onMapRequest(this: WindowManager, e: TXMapRequestEvent) =
  discard XMapWindow(this.display, e.window)

proc onEnterNotify(this: WindowManager, e: TXCrossingEvent) =
  discard XSetInputFocus(this.display, e.window, RevertToNone, CurrentTime)

proc onFocusIn(this: WindowManager, e: TXFocusChangeEvent) =
  discard XSetWindowBorder(this.display, e.window, borderColorFocused)

proc onFocusOut(this: WindowManager, e: TXFocusChangeEvent) =
  discard XSetWindowBorder(this.display, e.window, borderColorUnfocused)

