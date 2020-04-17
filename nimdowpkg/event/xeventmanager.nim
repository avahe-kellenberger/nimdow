import
  x11/xlib,
  tables,
  sets

type XEventListener* = proc(e: xlib.TXEvent): void

type XEventManager* = ref object of RootObj 
  listenerMap: Table[cint, HashSet[XEventListener]]
  eventPoller: iterator(display: xlib.PDisplay): xlib.TXEvent

proc newXEventManager*(): XEventManager =
  return XEventManager(listenerMap: initTable[cint, HashSet[XEventListener]]())

proc add*(this: XEventManager, theType: cint, listener: XEventListener): void =
  ## Adds a listener for the given x11/x event type.
  if theType notin this.listenerMap: (
    this.listenerMap[theType] = initHashSet[XEventListener]()
  )
  this.listenerMap[theType].incl(listener)

proc remove*(this: XEventManager, theType: cint, listener: XEventListener): void =
  ## Removes a listener.
  if theType in this.listenerMap:
    this.listenerMap[theType].excl(listener)

proc dispatch*(this: XEventManager, e: TXEvent): void =
  ## Dispatches an event to all listeners with the same TXEvent.theType
  if e.theType notin this.listenerMap:
    return
  let listeners = this.listenerMap[e.theType]
  for listener in listeners:
    listener(e)

iterator nextXEvent(display: xlib.PDisplay): xlib.TXEvent {.closure.} =
  ## Polls for `TXEvent`s
  var event: xlib.PXEvent 
  # XNextEvent returns 0 unless there is an error.
  while xlib.XNextEvent(display, event) == 0:
    yield event[]

proc hookXEvents*(this: XEventManager, display: xlib.PDisplay): void =
  ## Infinitely listens for and dispatches libx.TXEvents.
  ## This proc does not return.
  this.eventPoller = nextXEvent
  # TODO: This should probably be threaded.
  for event in this.eventPoller(display):
    this.dispatch(event)

