import
  x11 / [x, xlib],
  nimdowpkg/event/xeventmanager

var
  display: PDisplay
  rootWindow: TWindow
  windowAttribs: TXSetWindowAttributes
  eventManager: XEventManager

proc initXWindowInfo(): PDisplay =
  let tempDisplay = XOpenDisplay(nil)
  if tempDisplay == nil:
    quit "Failed to open display"
  return tempDisplay

proc setupListeners(eventManager: XEventManager) =
  # Example listener
  let listener: XEventListener = proc(e: TXEvent) =
    echo("Key event - ", e.theType)
    echo(e.xkey.keycode)
  eventManager.addListener(listener, KeyPress, KeyRelease)

when isMainModule:
  display = initXWindowInfo()
  rootWindow = DefaultRootWindow(display)

  # Listen for events defined by eventMask.
  # See https://tronche.com/gui/x/xlib/events/processing-overview.html#SubstructureRedirectMask
  # Events bubble up the hierarchy to the root window.
  windowAttribs.eventMask =
    SubstructureRedirectMask or
    SubstructureNotifyMask or
    ButtonPressMask or PointerMotionMask or
    EnterWindowMask or
    LeaveWindowMask or
    StructureNotifyMask or
    PropertyChangeMask

  # TODO: Dwm uses the below method, but according to https://tronche.com/gui/x/xlib/event-handling/selecting.html
  # we should only have to choose one to register for events (based on the supplied windowAttribs.eventMask)
  discard XChangeWindowAttributes(display, rootWindow, CWEventMask or CWCursor, addr(windowAttribs))
  discard XSelectInput(display, rootWindow, windowAttribs.eventMask);

  eventManager = newXEventManager()
  setupListeners(eventManager)
  eventManager.hookXEvents(display)

