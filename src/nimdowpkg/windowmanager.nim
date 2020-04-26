import
  sugar,
  tables,
  x11 / [x, xlib],
  config/config,
  event/xeventhandler,
  event/xeventmanager

converter toTBool(x: bool): TBool = x.TBool
converter toBool(x: TBool): bool = x.bool

type
  WindowManager* = ref object
    display*: PDisplay
    rootWindow*: TWindow
    xEventHandler: XEventHandler

proc openDisplay(this: WindowManager): PDisplay
proc configureConfigActions*(this: WindowManager)
proc configureRootWindow(this: WindowManager): TWindow
# Custom WM actions
proc testAction*(this: WindowManager)
proc destroySelectedWindow(this: WindowManager)

proc newWindowManager*(eventManager: XEventManager): WindowManager =
  result = WindowManager()
  result.display = result.openDisplay()
  result.rootWindow = result.configureRootWindow()
  result.xEventHandler = newXEventHandler(result.display, result.rootWindow)
  result.xEventHandler.initXEventHandler(eventManager)

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

