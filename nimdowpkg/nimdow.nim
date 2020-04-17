import
  sugar,
  x11/x,
  x11/xlib,
  event/xeventmanager

var
  display: PDisplay
  eventManager: XEventManager

proc initXWIndowInfo(): PDisplay =
  let tempDisplay = XOpenDisplay(nil)
  if tempDisplay == nil:
    quit "Failed to open display"
  return tempDisplay

when isMainModule:
  display = initXWIndowInfo()
  eventManager = newXEventManager()

  let listener: XEventListener = (e: TXEvent) => echo repr(e)
  eventManager.addListener(listener, x.KeyPress, x.KeyRelease)

  eventManager.hookXEvents(display)


