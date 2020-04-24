import
  x11/x,
  x11/xlib,
  nimdowpkg/event/xeventmanager,
  nimdowpkg/config/config,
  nimdowpkg/windowmanager

converter toTBool(x: bool): TBool = x.TBool

var
  display: PDisplay
  windowAttribs: TXSetWindowAttributes
  nimdow: WindowManager

proc initXWindowInfo(): PDisplay =
  let tempDisplay = XOpenDisplay(nil)
  if tempDisplay == nil:
    quit "Failed to open display"
  return tempDisplay

proc configureUserKeybindings(eventManager: XEventManager, rootWindow: TWindow) =
  # Order matters here.
  # `configureConfigActions` must be invoked before populating the config table.
  nimdow = newWindowManager(display, rootWindow)
  nimdow.configureConfigActions()
  config.populateConfigTable(display)
  config.hookConfig(eventManager)

when isMainModule:
  display = initXWindowInfo()
  let rootWindow = DefaultRootWindow(display)

  # Listen for events defined by eventMask.
  # See https://tronche.com/gui/x/xlib/events/processing-overview.html#SubstructureRedirectMask
  # Events bubble up the hierarchy to the root window.
  windowAttribs.eventMask =
    SubstructureRedirectMask or
    SubstructureNotifyMask or
    ButtonPressMask or
    PointerMotionMask or
    EnterWindowMask or
    LeaveWindowMask or
    StructureNotifyMask or
    PropertyChangeMask or
    KeyPressMask or
    KeyReleaseMask

  # Listen for events on the root window
  discard XChangeWindowAttributes(
    display,
    rootWindow,
    CWEventMask or CWCursor,
    addr(windowAttribs)
  )
  discard XSync(display, false)

  let eventManager = newXEventManager()
  eventManager.configureUserKeybindings(rootWindow)
  nimdow.initWindowManager(eventManager)
  eventManager.startEventListenerLoop(display)

