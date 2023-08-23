import
  x11/[x, xlib],
  tables,
  sets,
  osproc,
  times,
  safeseq,
  hashes

import ../logger

const CLOSE_PROCESS_CHECK_INTERVAL = 5.0

var
  timeLastCheckedProcesses: float
  currentTime: float

type
  XEventListener* = proc(e: XEvent)
  XEventManager* = ref object
    listenerMap: Table[cint, HashSet[XEventListener]]
    processes: SafeSeq[Process]

proc hash*(p: Process): Hash =
  !$p.processID

proc newXEventManager*(): XEventManager =
  XEventManager(
    listenerMap: initTable[cint, HashSet[XEventListener]](),
    processes: newSafeSeq[Process]()
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

when defined(debug):
  proc logEventTypeName(e: XEvent) =
   case e.theType:
      of KeyPress:
        log "KeyPress"
      of KeyRelease:
        log "KeyRelease"
      of ButtonPress:
        log "ButtonPress"
      of ButtonRelease:
        log "ButtonRelease"
      of MotionNotify:
        log "MotionNotify"
      of EnterNotify:
        log "EnterNotify"
      of LeaveNotify:
        log "LeaveNotify"
      of FocusIn:
        log "FocusIn"
      of FocusOut:
        log "FocusOut"
      of KeymapNotify:
        log "KeymapNotify"
      of Expose:
        log "Expose"
      of GraphicsExpose:
        log "GraphicsExpose"
      of NoExpose:
        log "NoExpose"
      of VisibilityNotify:
        log "VisibilityNotify"
      of CreateNotify:
        log "CreateNotify"
      of DestroyNotify:
        log "DestroyNotify"
      of UnmapNotify:
        log "UnmapNotify"
      of MapNotify:
        log "MapNotify"
      of MapRequest:
        log "MapRequest"
      of ReparentNotify:
        log "ReparentNotify"
      of ConfigureNotify:
        log "ConfigureNotify"
      of ConfigureRequest:
        log "ConfigureRequest"
      of GravityNotify:
        log "GravityNotify"
      of ResizeRequest:
        log "ResizeRequest"
      of CirculateNotify:
        log "CirculateNotify"
      of CirculateRequest:
        log "CirculateRequest"
      of PropertyNotify:
        log "PropertyNotify"
      of SelectionClear:
        log "SelectionClear"
      of SelectionRequest:
        log "SelectionRequest"
      of SelectionNotify:
        log "SelectionNotify"
      of ColormapNotify:
        log "ColormapNotify"
      of ClientMessage:
        log "ClientMessage"
      of MappingNotify:
        log "MappingNotify"
      of GenericEvent:
        log "GenericEvent"
      else:
        log "?"

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

