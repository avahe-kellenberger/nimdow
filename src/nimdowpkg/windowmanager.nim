import
  sugar,
  x11 / [x, xlib],
  config/config,
  event/xeventmanager

type
  WindowManager* = ref object
    display: PDisplay
    rootWindow: TWindow

proc configureConfigActions*(this: WindowManager)
proc frameWindow(this: WindowManager, window: TWindow)

# Custom WM actions
proc testAction*()
proc testAction2*()

# XEvent handlers
proc onCreateNotify(this: WindowManager, e: TXCreateWindowEvent)
proc onConfigureRequest(this: WindowManager, e: TXConfigureRequestEvent)
proc onMapRequest(this: WindowManager, e: TXMapRequestEvent)

proc newWindowManager*(display: PDisplay, rootWindow: TWindow): WindowManager =
  WindowManager(
    display: display,
    rootWindow: rootWindow
  )

proc initWindowManager*(this: WindowManager, eventManager: XEventManager) =
  # TODO: Can clean this up with a template probably
  eventManager.addListener((e: TXEvent) => onCreateNotify(this, e.xcreatewindow), CreateNotify)
  eventManager.addListener((e: TXEvent) => onConfigureRequest(this, e.xconfigurerequest), ConfigureRequest)
  eventManager.addListener((e: TXEvent) => onMapRequest(this, e.xmaprequest), MapRequest)

proc configureConfigActions*(this: WindowManager) =
  ## Maps available user configuration options to window manager actions.
  config.configureAction("testAction", testAction)
  config.configureAction("testAction2", testAction2)

proc testAction*() =
  echo "I did a thing with the windows"

proc testAction2*() =
  echo "I did a ANOTHER thing with the windows"

proc onCreateNotify(this: WindowManager, e: TXCreateWindowEvent) =
  # NOTE: We don't need to do anything on CreateNotify events.
  discard

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
  discard XConfigureWindow(
    this.display,
    e.window,
    cuint(e.value_mask),
    addr(changes)
  )

proc onMapRequest(this: WindowManager, e: TXMapRequestEvent) =
  this.frameWindow(e.window)
  discard XMapWindow(this.display, e.window)

proc frameWindow(this: WindowManager, window: TWindow) =
  ## Creates a parent window that encapsulates the given window.
  ## This new frame window is a direct child of the root window.
  ## The given window becomes a direct child of the new frame.

  # TODO: We need to set up window border properties with the config file
  let borderWidth = 2
  let borderColor = 0x3355BB
  let backgroundColor = 0x333333

  var windowAttr: TXWindowAttributes
  discard XGetWindowAttributes(this.display, window, addr(windowAttr))
  let frame: TWindow = XCreateSimpleWindow(
    this.display,
    this.rootWindow,
    windowAttr.x,
    windowAttr.y,
    cuint(windowAttr.width),
    cuint(windowAttr.height),
    cuint(borderWidth),
    culong(borderColor),
    culong(backgroundColor)
  )
  discard XSelectInput(
    this.display,
    frame,
    SubstructureRedirectMask or SubstructureNotifyMask
  )
  discard XAddToSaveSet(this.display, window)
  discard XReparentWindow(this.display, window, frame, 0, 0)
  discard XMapWindow(this.display, frame)

