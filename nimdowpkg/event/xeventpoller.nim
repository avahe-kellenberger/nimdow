import
  x11/xlib

iterator nextXEvent*(display: xlib.PDisplay): xlib.TXEvent {.closure.} =
  ## Polls for `TXEvent`s
  var event: xlib.PXEvent 
  # NOTE: XNextEvent returns 0 unless there is an error.
  while xlib.XNextEvent(display, event) == 0:
    yield event[]

