import
  sugar,
  tables,
  sets,
  x11 / [x, xlib],
  tag,
  config/config,
  event/xeventhandler,
  event/xeventmanager,
  layouts/layout,
  layouts/masterstacklayout

converter intToCint(x: int): cint = x.cint
converter intToCUint(x: int): cuint = x.cuint
converter toTBool(x: bool): TBool = x.TBool
converter toBool(x: TBool): bool = x.bool

type
  WindowManager* = ref object
    display*: PDisplay
    rootWindow*: TWindow
    xEventHandler: XEventHandler
    tagTable: OrderedTable[Tag, OrderedSet[TWindow]]
    selectedTag: Tag

proc openDisplay(this: WindowManager): PDisplay
proc configureConfigActions*(this: WindowManager)
proc configureRootWindow(this: WindowManager): TWindow
proc configureWindowMappingListeners(this: WindowManager, eventManager: XEventManager)
proc addWindowToSelectedTags(this: WindowManager, e: TXMapEvent)
proc removeWindowFromTagTable(this: WindowManager, e: TXUnmapEvent)
proc layout(this: WindowManager)
# Custom WM actions
proc testAction*(this: WindowManager)
proc destroySelectedWindow(this: WindowManager)

proc newWindowManager*(eventManager: XEventManager): WindowManager =
  result = WindowManager()
  result.display = result.openDisplay()
  result.rootWindow = result.configureRootWindow()
  result.xEventHandler = newXEventHandler(result.display, result.rootWindow)
  result.xEventHandler.initXEventHandler(eventManager)

  result.tagTable = OrderedTable[Tag, OrderedSet[TWindow]]()
  for i in 1..9:
    let tag: Tag = newTag(
      id = i,
      layout = newMasterStackLayout(
        gapSize = 48,
        borderSize = 2,
        masterSlots = 2
      )
    )
    result.tagTable[tag] = initOrderedSet[TWindow]()

  # View first tag by default
  for tag in result.tagTable.keys():
    result.selectedTag = tag
    break
  result.configureWindowMappingListeners(eventManager)

proc configureWindowMappingListeners(this: WindowManager, eventManager: XEventManager) =
  eventManager.addListener((e: TXEvent) => addWindowToSelectedTags(this, e.xmap), MapNotify)
  eventManager.addListener((e: TXEvent) => removeWindowFromTagTable(this, e.xunmap), UnmapNotify)

proc addWindowToSelectedTags(this: WindowManager, e: TXMapEvent) =
  this.tagTable[this.selectedTag].incl(e.window)
  this.layout()

proc removeWindowFromTagTable(this: WindowManager, e: TXUnmapEvent) =
  let numWindowsInSelectedTag = this.tagTable[this.selectedTag].len
  for windows in this.tagTable.mvalues():
    windows.excl(e.window)
  # Check if the number of windows on the current tag has changed
  if numWindowsInSelectedTag != this.tagTable[this.selectedTag].len:
    this.layout()

proc layout(this: WindowManager) =
  ## Revalidates the current layout of the viewed tag(s).
  this.selectedTag.layout.doLayout(
    this.display,
    this.tagTable[this.selectedTag]
  )

proc openDisplay(this: WindowManager): PDisplay =
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
  this.xEventHandler.hookConfigKeys()

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

