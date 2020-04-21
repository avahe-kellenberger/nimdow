import
  x11/xlib,
  tables,
  sets

type
  XEventListener* = proc(e: TXEvent)
  XEventManager* = ref object
    listenerMap: Table[cint, HashSet[XEventListener]]
    event: TXEvent

proc newXEventManager*(): XEventManager =
  XEventManager(listenerMap: initTable[cint, HashSet[XEventListener]]())

proc addListener*(this: XEventManager, listener: XEventListener, types: varargs[cint]) =
  ## Adds a listener for the given x11/x event type.
  for theType in types:
    if theType notin this.listenerMap:
      this.listenerMap[theType] = initHashSet[XEventListener]()
    this.listenerMap[theType].incl(listener)

proc removeListener*(this: XEventManager, listener: XEventListener, types: varargs[cint]) =
  ## Removes a listener.
  for theType in types:
    if theType in this.listenerMap:
      this.listenerMap[theType].excl(listener)

proc dispatchEvent*(this: XEventManager, e: TXEvent) =
  ## Dispatches an event to all listeners with the same TXEvent.theType
  
  # We are not listening for this event type - exit.
  if e.theType notin this.listenerMap:
    return

  let listeners = this.listenerMap[e.theType]
  for listener in listeners:
    listener(e)

proc hookXEvents*(this: XEventManager, display: PDisplay) =
  ## Infinitely listens for and dispatches libx.TXEvents.
  ## This proc will not return unless there is an error.

  # XNextEvent returns 0 unless there is an error.
  while XNextEvent(display, addr(this.event)) == 0:
    this.dispatchEvent(this.event)

