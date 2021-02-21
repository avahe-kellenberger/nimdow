import
  x11/xlib,
  os,
  parsetoml,
  nimdowpkg/windowmanager,
  nimdowpkg/event/xeventmanager,
  nimdowpkg/config/configloader,
  nimdowpkg/wmcommands,
  nimdowpkg/ipc/cli,
  nimdowpkg/ipc/ipc,
  nimdowpkg/logger

when isMainModule:
  # Needed - See https://www.x.org/releases/X11R7.6/doc/man/man3/XInitThreads.3.xhtml
  if XInitThreads() == 0:
    echo "ERROR - Could not XInitThreads!"
    quit(1)

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

  # Sync the display before listening for events.
  discard XSync(nimdow.display, false.XBool)
  # Start X event loop
  # var xEventLoopThread: Thread[PDisplay]
  # xEventLoopThread.createThread(startEventListenerLoop, nimdow.display)

  # Start IPC
  var ipcThread: Thread[void]
  ipcThread.createThread(ipc.listen)

  var event: XEvent
  while true:
    block xeventHandler:
      while XPending(nimdow.display) > 0:
        discard XNextEvent(nimdow.display, event.addr)
        eventManager.dispatchEvent(event)
      eventManager.checkForProcessesToClose()

    block ipcHandler:
      let data = ipcChannel.tryRecv()
      if data.dataAvailable:
        let commandOpt = parseCommand(data.msg)
        if commandOpt.isSome:
          echo "Got command: " & $commandOpt.get

    # block xeventHandler:
    #   var data: tuple[dataAvailable: bool, msg: XEvent]
    #   while true:
    #     data = eventChannel.tryRecv()
    #     if not data.dataAvailable:
    #       break
    #     XLockDisplay(nimdow.display)
    #     eventManager.dispatchEvent(data.msg)
    #     XUnlockDisplay(nimdow.display)
    #   eventManager.checkForProcessesToClose()

    # TODO: There must be something better... Right?
    # sleep(17)

  # After other threads stop running
  eventManager.closeFinishedProcesses()
  discard XCloseDisplay(nimdow.display)

