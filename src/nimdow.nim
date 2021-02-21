import
  x11/xlib,
  os,
  net,
  selectors,
  parsetoml

import
  nimdowpkg/windowmanager,
  nimdowpkg/event/xeventmanager,
  nimdowpkg/config/configloader,
  nimdowpkg/ipc/cli,
  nimdowpkg/ipc/ipc,
  nimdowpkg/logger

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
      if event.fd == displayFd:
        while XPending(nimdow.display) > 0:
          discard XNextEvent(nimdow.display, xEvent.addr)
          eventManager.dispatchEvent(xEvent)
        eventManager.checkForProcessesToClose()

      elif event.fd == ipcSocketFd:
        var client: Socket
        try:
          ipcSocket.accept(client, flags = {})
          let received = client.recv(MaxLineLength)
          log "Received " & received
          client.close()
        except:
          # Client disconnected when we tried to accept.
          discard

  # TODO: A way to invoke these when the program is terminating?
  # eventManager.closeFinishedProcesses()
  # discard XCloseDisplay(nimdow.display)

