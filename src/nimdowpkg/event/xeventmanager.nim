import
  x11/xlib,
  tables,
  sets,
  osproc,
  times,
  safeset,
  hashes

const CLOSE_PROCESS_CHECK_INTERVAL = 5.0

var
  timeLastCheckedProcesses: float
  currentTime: float

type
  XEventListener* = proc(e: XEvent)
  XEventManager* = ref object
    listenerMap: Table[cint, HashSet[XEventListener]]
    processes: SafeSet[Process]

proc hash*(p: Process): Hash =
  !$p.processID

proc newXEventManager*(): XEventManager =
  XEventManager(
    listenerMap: initTable[cint, HashSet[XEventListener]](),
    processes: newSafeSet[Process]()
  )

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
  if this.listenerMap.hasKey(e.theType):
    let listeners = this.listenerMap[e.theType]
    for listener in listeners:
      listener(e)

proc submitProcess*(this: XEventManager, process: Process) =
  this.processes.add(process)

proc closeFinishedProcesses*(this: XEventManager) =
  ## Closes any finished processes
  ## and removes them from the processes seqeunce.
  for process in this.processes:
    if not process.running():
      process.close()
      this.processes.remove(process)

proc checkForProcessesToClose*(this: XEventManager) =
  ## Check for closed processes periodically.
  currentTime = epochTime()
  if timeLastCheckedProcesses - currentTime >= CLOSE_PROCESS_CHECK_INTERVAL:
    this.closeFinishedProcesses()
    timeLastCheckedProcesses = currentTime

