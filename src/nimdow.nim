import
  os,
  parsetoml,
  nimdowpkg/event/xeventmanager,
  nimdowpkg/windowmanager,
  nimdowpkg/config/configloader

when isMainModule:
  let loadedConfig = newConfig()
  var configTable: TomlTable

  when declared(commandLineParams):
    let params = commandLineParams()
    if params.len == 1:
      let param = params[0].string
      if param == "-v" or param == "--version":
        echo "Nimdow v0.6.1"
        quit()
      else:
        # If given a parameter for a config file, use it instead of the default.
        configloader.configLoc = params[0].string

  let eventManager = newXEventManager()
  let nimdow = newWindowManager(eventManager)
  loadedConfig.runAutostartCommands(configTable)
  eventManager.startEventListenerLoop(nimdow.display)

