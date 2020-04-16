import
  x11/xlib,
  xeventpoller

var
  display: TXDisplay

proc initXWIndowInfo(): xlib.TXDisplay =
  let tempDisplay = XOpenDisplay(nil)
  if tempDisplay == nil:
    quit "Failed to open display"
  return tempDisplay[]

when isMainModule:
  display = initXWIndowInfo()
  for event in xeventpoller.nextXEvent(display.addr):
    echo repr(event)

