import
  x11/xlib,
  os,
  net,
  selectors,
  strutils,
  strformat,
  parsetoml

import
  nimdowpkg/windowmanager,
  nimdowpkg/event/xeventmanager,
  nimdowpkg/config/configloader,
  nimdowpkg/ipc/cli,
  nimdowpkg/ipc/ipc,
  nimdowpkg/wmcommands,
  nimdowpkg/keys/keyutils,
  nimdowpkg/logger

proc handleCommand(
  str: string,
  windowmanager: WindowManager,
  actionIdentifierTable: Table[string, Action]
) =
  let split = str.split()
  if split.len < 2:
    log "Not enough arguments.", lvlWarn
    return

  if split[0] != ipcPrefix:
    log fmt"Commands must be prefixed with {ipcPrefix}", lvlWarn
    return

  let command = split[1].toLower()
  let commandOpt = parseCommand(command)
  if commandOpt.isSome:
    if actionIdentifierTable.hasKey($command):
      var keycode = 0
      if split.len > 2:
        keycode = split[2].toKeycode(windowmanager.display)
      actionIdentifierTable[$command]((keycode, 0))

when isMainModule:
  if not cli.handleCommandLineParams():
    quit()

  let
    eventManager = newXEventManager()
    loadedConfig = newConfig(eventManager)

  var configTable: TomlTable
  try:
    configTable = loadConfigFile()
  except:
    log getCurrentExceptionMsg(), lvlError

  let nimdow = newWindowManager(eventManager, loadedConfig, configTable)

  logger.enabled = loadedConfig.loggingEnabled
  log "Starting Nimdow " & version

  try:
    loadedConfig.populateAppRules(configTable)
    loadedConfig.runAutostartCommands(configTable)
  except:
    log getCurrentExceptionMsg(), lvlError

  let
    selector = newSelector[pointer]()
    displayFd = ConnectionNumber(nimdow.display).int
    ipcSocket = ipc.initIPCSocket()
    ipcSocketFd = ipcSocket.getFd().int

  selector.registerHandle(displayFd, {Read}, nil)
  selector.registerHandle(ipcSocketFd, {Read}, nil)

  # Sync the display before listening for events.
  discard XSync(nimdow.display, false.XBool)
  var xEvent: XEvent

  while true:
    for event in selector.select(-1):

      # X11 Event(s) Received
      if event.fd == displayFd:
        while XPending(nimdow.display) > 0:
          discard XNextEvent(nimdow.display, xEvent.addr)
          eventManager.dispatchEvent(xEvent)
        eventManager.checkForProcessesToClose()

      # IPC Socket
      elif event.fd == ipcSocketFd:
        var client: Socket
        try:
          ipcSocket.accept(client, flags = {})
          let received = client.recv(MaxLineLength)
          client.close()
          handleCommand(received, nimdow, loadedConfig.actionIdentifierTable)
        except:
          # Client disconnected when we tried to accept.
          discard

  # TODO: A way to invoke these when the program is terminating?
  # eventManager.closeFinishedProcesses()
  # discard XCloseDisplay(nimdow.display)

