import
  x11 / [x, xlib],
  os,
  parsetoml,
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

  var thread: Thread[void]
  thread.createThread(ipc.listen)

  # let listener = proc(e: XEvent) =
  #   echo "aoeu"

  # eventManager.addListener(listener, GenericEvent)

  eventManager.startEventListenerLoop(nimdow.display)

