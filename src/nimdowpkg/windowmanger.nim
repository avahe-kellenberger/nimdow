import config/config  

proc testAction*() =
  echo "I did a thing with the windows"

proc testAction2*() =
  echo "I did a ANOTHER thing with the windows"

proc configureActions*() =
  ## Maps available user configuration options to window manager actions.
  config.configureAction("testAction", testAction)
  config.configureAction("testAction2", testAction2)

