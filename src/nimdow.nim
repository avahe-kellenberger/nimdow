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

proc cleanMask(mask: int): int = 
  ## Creates a uniform mask that can be used with
  ## masks defined in x11/x.nim and TXKeyEvent.state
  mask and (not LockMask) and
  (ShiftMask or ControlMask or Mod1Mask or Mod2Mask or Mod3Mask or Mod4Mask or Mod5Mask)

proc setupListeners(eventManager: XEventManager) =
  # Example listener
  let listener: XEventListener = proc(e: TXEvent) =
    let keycode = cuint(XKeysymToKeycode(display, XStringToKeysym("d")))
    if keycode == e.xkey.keycode and
      cleanMask(ControlMask) == cleanMask(int(e.xkey.state)):
        echo "Pressed Control + d!"

  eventManager.addListener(listener, KeyPress)

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

  eventManager = newXEventManager()
  setupListeners(eventManager)
  eventManager.hookXEvents(display)

