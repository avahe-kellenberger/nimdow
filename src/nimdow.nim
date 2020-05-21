import
  nimdowpkg/event/xeventmanager,
  nimdowpkg/windowmanager,
  nimdowpkg/config/config

when isMainModule:
  let eventManager = newXEventManager()
  let nimdow = newWindowManager(eventManager)
  nimdow.configureConfigActions()
  # Order matters here.
  # `configureConfigActions` must be invoked before populating the config table.
  config.populateKeyComboTable(nimdow.display)
  config.hookConfig(eventManager)
  nimdow.hookConfigKeys()
  eventManager.startEventListenerLoop(nimdow.display)

