import
  parsetoml,
  nimdowpkg/event/xeventmanager,
  nimdowpkg/windowmanager,
  nimdowpkg/config/configloader

when isMainModule:
  let loadedConfig = newConfig()
  let configTable: TomlTable = configloader.loadConfigFile()
  # General settings need to be populated before the windowmanager is created.
  loadedConfig.populateGeneralSettings(configTable)

  let eventManager = newXEventManager()
  let nimdow = newWindowManager(eventManager, loadedConfig)
  nimdow.mapConfigActions()

  # Order matters here.
  loadedConfig.populateKeyComboTable(configTable, nimdow.display)
  loadedConfig.hookConfig(eventManager)
  nimdow.hookConfigKeys()
  eventManager.startEventListenerLoop(nimdow.display)

