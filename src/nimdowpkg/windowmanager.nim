import
  sugar,
  tables,
  x11 / [x, xlib],
  config/config,
  event/xeventmanager

converter cUlongToCUint(x: culong): cuint = x.cuint
converter intToCint(x: int): cint = x.cint
converter intToCUint(x: int): cuint = x.cuint
converter toTBool(x: bool): TBool = x.TBool
converter toBool(x: TBool): bool = x.bool

const borderColorFocused = 0x3355BB
const borderColorUnfocused = 0x335544
const borderWidth = 2

type
  WindowManager* = ref object
    display: PDisplay
    rootWindow: TWindow

proc configureConfigActions*(this: WindowManager)
# Custom WM actions
proc testAction*(this: WindowManager)
proc destroySelectedWindow(this: WindowManager)
# XEvent handlers
proc errorHandler(disp: PDisplay, error: PXErrorEvent): cint{.cdecl.}
proc onCreateNotify(this: WindowManager, e: TXCreateWindowEvent)
proc onConfigureRequest(this: WindowManager, e: TXConfigureRequestEvent)
proc onMapRequest(this: WindowManager, e: TXMapRequestEvent)
proc onEnterNotify(this: WindowManager, e: TXCrossingEvent)
proc onFocusIn(this: WindowManager, e: TXFocusChangeEvent)
proc onFocusOut(this: WindowManager, e: TXFocusChangeEvent)

proc newWindowManager*(display: PDisplay, rootWindow: TWindow): WindowManager =
  WindowManager(display: display, rootWindow: rootWindow)

proc initWindowManager*(this: WindowManager, eventManager: XEventManager) =
  discard XSetErrorHandler(errorHandler)
  # TODO: Can clean this up with a template probably
  eventManager.addListener((e: TXEvent) => onCreateNotify(this, e.xcreatewindow), CreateNotify)
  eventManager.addListener((e: TXEvent) => onConfigureRequest(this, e.xconfigurerequest), ConfigureRequest)
  eventManager.addListener((e: TXEvent) => onMapRequest(this, e.xmaprequest), MapRequest)
  eventManager.addListener((e: TXEvent) => onEnterNotify(this, e.xcrossing), EnterNotify)
  eventManager.addListener((e: TXEvent) => onFocusIn(this, e.xfocus), FocusIn)
  eventManager.addListener((e: TXEvent) => onFocusOut(this, e.xfocus), FocusOut)

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

proc configureConfigActions*(this: WindowManager) =
  ## Maps available user configuration options to window manager actions.
  config.configureAction("testAction", () => testAction(this))
  config.configureAction("destroySelectedWindow", () => destroySelectedWindow(this))

proc testAction*(this: WindowManager) =
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

proc errorHandler(disp: PDisplay, error: PXErrorEvent): cint{.cdecl.} =
  echo "Error: ", error.theType

proc onCreateNotify(this: WindowManager, e: TXCreateWindowEvent) =
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

