import
  os, 
  parsetoml,
  nimdowpkg/event/xeventmanager,
  nimdowpkg/windowmanager,
  nimdowpkg/config/configloader

when isMainModule:
  let loadedConfig = newConfig()
  var configTable: TomlTable
  
  # If given a parameter for a config file, use it instead.
  var configLoc: string
  when declared(commandLineParams):
    let params = commandLineParams()
    if params.len == 1:
      configLoc = params[0].string

  configTable = configloader.loadConfigFile(configLoc)
  # General settings need to be populated before the windowmanager is created.
  loadedConfig.populateGeneralSettings(configTable)

  let eventManager = newXEventManager()
  let nimdow = newWindowManager(eventManager, loadedConfig)
  nimdow.mapConfigActions()

  # Order matters here.
  loadedConfig.populateKeyComboTable(configTable, nimdow.display)
  loadedConfig.hookConfig(eventManager)
  nimdow.hookConfigKeys()
  loadedConfig.runAutostartCommands(configTable)
  eventManager.startEventListenerLoop(nimdow.display)
