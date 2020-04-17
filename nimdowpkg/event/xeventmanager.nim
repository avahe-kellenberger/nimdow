import
  x11/xlib,
  tables,
  sets

type
  XEventListener* = proc(e: TXEvent)
  XEventManager* = ref object
    listenerMap: Table[int, HashSet[XEventListener]]

proc newXEventManager*(): XEventManager =
  XEventManager(listenerMap: initTable[int, HashSet[XEventListener]]())

proc bitor(bits: varargs[int]): int =
  for bit in bits:
    result = result or bit
  return result

proc addListener*(this: XEventManager, listener: XEventListener, types: varargs[int]) =
  ## Adds a listener for the given x11/x event type.
  let theType = bitor(types)
  if theType notin this.listenerMap:
    this.listenerMap[theType] = initHashSet[XEventListener]()

  this.listenerMap[theType].incl(listener)

proc removeListener*(this: XEventManager, listener: XEventListener, theTypes: varargs[int]) =
  ## Removes a listener.
  let theType = bitor(theTypes)
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
  var event: PXEvent 
  # XNextEvent returns 0 unless there is an error.
  while XNextEvent(display, event) == 0:
    this.dispatchEvent(event[])

