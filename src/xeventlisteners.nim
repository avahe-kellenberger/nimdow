import
  x11/xlib,
  tables,
  sets

type XEventListener* = proc(e: xlib.TXEvent): void
var listenerMap = newTable[cint, HashSet[XEventListener]]()

proc add*(theType: cint, listener: XEventListener): void =
  ## Adds a listener for the given x11/x event type.
  if theType notin listenerMap: (
    listenerMap[theType] = initHashSet[XEventListener]()
  )
  listenerMap[theType].incl(listener)

proc remove*(theType: cint, listener: XEventListener): void =
  ## Removes a listener.
  if theType notin listenerMap:
    return

  listenerMap[theType].excl(listener)

proc dispatch*(e: TXEvent): void =
  ## Dispatches an event to all listeners with the same TXEvent.theType
  if e.theType notin listenerMap:
    return

  let listeners = listenerMap[e.theType]
  for listener in listeners:
    listener(e)

