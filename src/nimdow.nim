import
  os,
  nimdowpkg/event/xeventmanager,
  nimdowpkg/windowmanager,
  nimdowpkg/config/configloader

when isMainModule:
  when declared(commandLineParams):
    let params = commandLineParams()
    if params.len == 1:
      let param = params[0].string
      if param == "-v" or param == "--version":
        echo "Nimdow v0.6.8"
        quit()
      else:
        # If given a parameter for a config file, use it instead of the default.
        configloader.configLoc = params[0].string
    else:
      configloader.configLoc = findConfigPath()

  let
    loadedConfig = newConfig()
    configTable = loadConfigFile()

  let eventManager = newXEventManager()
  let nimdow = newWindowManager(eventManager, loadedConfig, configTable)
  loadedConfig.runAutostartCommands(configTable)
  eventManager.startEventListenerLoop(nimdow.display)

