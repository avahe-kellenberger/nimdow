import 
  x11/x,
  x11/xlib,
  converters

proc bitor(values: varargs[int32]): cuint =
  ## `or` all values together, and convert to cuint.
  var bits: int32 = 0
  for v in items(values):
    bits = bits or v
  return converters.int32toCUint(bits)

proc grabKey*(display: xlib.PDisplay, key: string, modifiers: varargs[int32]): void =
  ## Invokes XGrabKey with the given XString and modifiers on the given display.
  discard XGrabKey(
    display,
    # Convert the key to a Keycode
    xlib.XKeysymToKeycode(display, XStringToKeysym(key)),
    # Modifiers must be of type cuint
    bitor(modifiers),
    # grab_window (window that grabs the events)
    xlib.DefaultRootWindow(display),
    # owner_events (whether the keyboard events are to be reported as usual)
    true,
    # pointer_mode
    x.GrabModeAsync,
    # keyboard_mode
    x.GrabModeAsync
  )

proc grabButton*(display: xlib.PDisplay, bool, button: int32, modifiers: varargs[int32]): void =
  ## Invokes XGrabKey with the given XString and modifiers on the given display.
  discard XGrabButton(
    display,
    x.Button1,
    bitor(modifiers),
    xlib.DefaultRootWindow(display),
    true,
    # Listen for button press and button release
    x.ButtonPressMask or x.ButtonReleaseMask,
    x.GrabModeAsync,
    x.GrabModeAsync,
    x.None,
    x.None
  )



