import
  x11/xlib, x11/x,
  displayutils,
  converters

type XWindowInfo = object
  display*: xlib.PDisplay
  attr*: xlib.TXWindowAttributes
  start*: xlib.TXButtonEvent
  event*: xlib.TXEvent

var
  winInfo: XWindowInfo

proc initXWIndowInfo(winInfo: var XWindowInfo): XWIndowInfo =
  winInfo.display = XOpenDisplay(nil)
  if winInfo.display == nil:
    quit "Failed to open display"

  winInfo.display.grabKey("F1", x.Mod4Mask)
  winInfo.display.grabButton(x.Button1, x.Mod4Mask)
  winInfo.display.grabButton(x.Button3, x.Mod4Mask)

  winInfo.start.subwindow = None

  return winInfo

proc onKeyPress(event: TXKeyEvent): void =
  discard XRaiseWindow(winInfo.display, event.subwindow)

proc onButtonPress(event: TXButtonEvent): void = 
  # TODO: The Mask used here only checks when a button is released AND there is a pointer motion.
  #
  # To have windows focused when the mouse moves over them, we need a general pointer motion mask.
  # PointerMotionMask - The client application receives MotionNotify events independent of the state of the pointer buttons. 
  # See https://www.x.org/releases/current/doc/libX11/libX11/libX11.html#idm140481285264384
  discard XGrabPointer(
    # Display *display
    winInfo.display,
    # Window grab_window
    event.subwindow,
    # Bool owner_events
    converters.toTBool(true),
    # unsigned int event_mask
    x.PointerMotionMask or x.ButtonReleaseMask,
    # int pointer_mode
    x.GrabModeAsync,
    # int keyboard_mode
    x.GrabModeAsync,
    # Window grab_window
    x.None,
    # Cursor cursor
    x.None,
    # Time time
    x.CurrentTime
  )
  discard XGetWindowAttributes(winInfo.display, event.subwindow, winInfo.attr.addr);
  winInfo.start = event;

proc onMotionNotify(motionEvent: TXMotionEvent, buttonEvent: TXButtonEvent): void =
  # echo "Window: ", motionEvent.window, " subwindow: ", motionEvent.subwindow, " root: ", motionEvent.root
  var
    xdiff = buttonEvent.x_root - winInfo.start.x_root
    ydiff = buttonEvent.y_root - winInfo.start.y_root
  discard XMoveResizeWindow(
    winInfo.display,
    motionEvent.window,
    winInfo.attr.x + (if winInfo.start.button == 1: xdiff else: 0),
    winInfo.attr.y + (if winInfo.start.button==1: ydiff else: 0),
    max(1, winInfo.attr.width + (if winInfo.start.button==3: xdiff else: 0)),
    max(1, winInfo.attr.height + (if winInfo.start.button==3: ydiff else: 0))
  )

when isMainModule:
  winInfo = initXWIndowInfo(winInfo)

  while true:
    # The XNextEvent function copies the first event from the event queue
    # into the specified XEvent structure and then removes it from the queue.
    # If the event queue is empty, XNextEvent flushes the output buffer and blocks until an event is received.
    discard XNextEvent(winInfo.display, winInfo.event.addr)

    # TODO: Set up switch case with external procs for event listeners.
    if winInfo.event.theType == x.KeyPress:
      var event = cast[PXKeyEvent](winInfo.event.addr)[]
      if not event.subwindow.addr.isNil:
        #discard XLowerWindow(winInfo.display, event.subwindow)
        onKeyPress(event)
    elif winInfo.event.theType == x.ButtonPress:
      var event: TXButtonEvent = cast[PXButtonEvent](winInfo.event.addr)[]
      if event.subwindow.addr.isNil or event.subwindow == x.None:
        continue 
      onButtonPress(event)
    elif winInfo.event.theType == x.MotionNotify:
      var motionEvent: TXMotionEvent = cast[PXMotionEvent](winInfo.event.addr)[]
      var buttonEvent: TXButtonEvent = cast[PXButtonEvent](winInfo.event.addr)[]
      # Pops all MotionNotify evennts from the queue and places the most recent into winInfo.event.addr
      while XCheckTypedEvent(winInfo.display, x.MotionNotify, winInfo.event.addr):
        continue
      onMotionNotify(motionEvent, buttonEvent)
    elif winInfo.event.theType == x.ButtonRelease:
      discard XUngrabPointer(winInfo.display, x.CurrentTime)
    else:
      continue

