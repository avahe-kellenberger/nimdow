import
  os,
  nimdowpkg/windowmanager,
  nimdowpkg/event/xeventmanager,
  nimdowpkg/config/configloader,
  nimdowpkg/logger

when isMainModule:
  const version = "v0.7.1"
  when declared(commandLineParams):
    let params = commandLineParams()
    if params.len == 1:
      let param = params[0].string
      if param == "-v" or param == "--version":
        echo "Nimdow ", version
        quit()
      else:
        # If given a parameter for a config file, use it instead of the default.
        configloader.configLoc = params[0].string
    else:
      configloader.configLoc = findConfigPath()

  let
    eventManager = newXEventManager()
    loadedConfig = newConfig(eventManager)
    configTable = loadConfigFile()

  let nimdow = newWindowManager(eventManager, loadedConfig, configTable)

  logger.enabled = loadedConfig.loggingEnabled
  log("Starting Nimdow " & version)

  loadedConfig.runAutostartCommands(configTable)
  eventManager.startEventListenerLoop(nimdow.display)

