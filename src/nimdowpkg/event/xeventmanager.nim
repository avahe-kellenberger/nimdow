import
  x11/xlib,
  tables,
  sets,
  osproc,
  times

const CLOSE_PROCESS_CHECK_INTERVAL = 5.0

var
  timeLastCheckedProcesses: float
  currentTime: float

type
  XEventListener* = proc(e: XEvent)
  XEventManager* = ref object
    listenerMap: Table[cint, HashSet[XEventListener]]
    processes: seq[Process]

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

proc dispatchEvent*(this: XEventManager, e: XEvent) =
  ## Dispatches an event to all listeners with the same TXEvent.theType

  # We are not listening for this event type - exit.
  if e.theType notin this.listenerMap:
    return
  let listeners = this.listenerMap[e.theType]
  for listener in listeners:
    listener(e)

proc submitProcess*(this: XEventManager, process: Process) =
  this.processes.add(process)

proc closeFinishedProcesses*(this: XEventManager) =
  ## Closes any finished processes
  ## and removes them from the processes seqeunce.
  var i = 0
  while i < this.processes.len:
    let process = this.processes[i]
    if not process.running():
      process.close()
      this.processes.del(i)
    else:
      i.inc

proc checkForProcessesToClose*(this: XEventManager) =
  ## Check for closed processes periodically.
  currentTime = epochTime()
  if timeLastCheckedProcesses - currentTime >= CLOSE_PROCESS_CHECK_INTERVAL:
    this.closeFinishedProcesses()
    timeLastCheckedProcesses = currentTime

