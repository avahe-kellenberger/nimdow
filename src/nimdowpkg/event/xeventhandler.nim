import
  sugar,
  tables,
  x11 / [x, xlib],
  "../config/config",
  xeventmanager

converter intToCint(x: int): cint = x.cint
converter intToCUint(x: int): cuint = x.cuint
converter cUlongToCUint(x: culong): cuint = x.cuint
converter toTBool(x: bool): TBool = x.TBool
converter toBool(x: TBool): bool = x.bool

const borderColorFocused = 0x3355BB
const borderColorUnfocused = 0x335544
const borderWidth = 2

type
  XEventHandler* = ref object
    display: PDisplay
    rootWindow: TWindow

proc hookConfigKeys*(this: XEventHandler)
proc errorHandler(disp: PDisplay, error: PXErrorEvent): cint{.cdecl.}
proc onCreateNotify(this: XEventHandler, e: TXCreateWindowEvent)
proc onConfigureRequest(this: XEventHandler, e: TXConfigureRequestEvent)
proc onMapRequest(this: XEventHandler, e: TXMapRequestEvent)
proc onEnterNotify(this: XEventHandler, e: TXCrossingEvent)
proc onFocusIn(this: XEventHandler, e: TXFocusChangeEvent)
proc onFocusOut(this: XEventHandler, e: TXFocusChangeEvent)

proc newXEventHandler*(display: PDisplay, rootWindow: TWindow): XEventHandler =
  XEventHandler(display: display, rootWindow: rootWindow)

proc initXEventHandler*(this: XEventHandler, eventManager: XEventManager) =
  ## Hooks into various XEvents and 
  discard XSetErrorHandler(errorHandler)
  eventManager.addListener((e: TXEvent) => onCreateNotify(this, e.xcreatewindow), CreateNotify)
  eventManager.addListener((e: TXEvent) => onConfigureRequest(this, e.xconfigurerequest), ConfigureRequest)
  eventManager.addListener((e: TXEvent) => onMapRequest(this, e.xmaprequest), MapRequest)
  eventManager.addListener((e: TXEvent) => onEnterNotify(this, e.xcrossing), EnterNotify)
  eventManager.addListener((e: TXEvent) => onFocusIn(this, e.xfocus), FocusIn)
  eventManager.addListener((e: TXEvent) => onFocusOut(this, e.xfocus), FocusOut)

proc hookConfigKeys*(this: XEventHandler) =
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

proc errorHandler(disp: PDisplay, error: PXErrorEvent): cint{.cdecl.} =
  echo "Error: ", error.theType

proc onCreateNotify(this: XEventHandler, e: TXCreateWindowEvent) =
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

proc onConfigureRequest(this: XEventHandler, e: TXConfigureRequestEvent) =
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

proc onMapRequest(this: XEventHandler, e: TXMapRequestEvent) =
  discard XMapWindow(this.display, e.window)

proc onEnterNotify(this: XEventHandler, e: TXCrossingEvent) =
  discard XSetInputFocus(this.display, e.window, RevertToNone, CurrentTime)

proc onFocusIn(this: XEventHandler, e: TXFocusChangeEvent) =
  discard XSetWindowBorder(this.display, e.window, borderColorFocused)

proc onFocusOut(this: XEventHandler, e: TXFocusChangeEvent) =
  discard XSetWindowBorder(this.display, e.window, borderColorUnfocused)

