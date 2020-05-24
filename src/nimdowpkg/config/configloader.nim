import 
  os,
  osproc,
  parsetoml,
  tables,
  x11 / [x,  xlib],
  "../keys/keyutils",
  "../event/xeventmanager"

type
  KeyCombo* = tuple[keycode: int, modifiers: int]
  Action* = proc(keycode: int): void
  Config* = ref object
    identifierTable*: Table[string, Action]
    keyComboTable*: Table[KeyCombo, Action]
    gapSize*: uint

proc newConfig*(): Config =
  Config(
    identifierTable: initTable[string, Action](),
    keyComboTable: initTable[KeyCombo, Action](),
    gapSize: 48
  )

proc configureAction*(this: Config, actionName: string, actionInvokee: Action)
proc hookConfig*(this: Config, eventManager: XEventManager)
proc populateKeyComboTable*(this: Config, configTable: TomlTable, display: PDisplay)
proc findConfigPath(): string
proc populateControlAction(this: Config, display: PDisplay, action: string, configTable: TomlTable)
proc getKeyCombos(this: Config, configTable: TomlTable, display: PDisplay, action: string): seq[KeyCombo]
proc getKeysForAction(this: Config, configTable: TomlTable, action: string): seq[string]
proc getModifiersForAction(this: Config, configTable: TomlTable, action: string): seq[TomlValueRef]

proc getModifierMask(modifier: TomlValueRef): int =
  if modifier.kind != TomlValueKind.String:
    raise newException(Exception, "Invalid key configuration: " &
                       repr(modifier) & " is not a string")
  if not ModifierTable.hasKey(modifier.stringVal):
    raise newException(Exception, "Invalid key configuration: " &
                       repr(modifier) & " is not a a valid key modifier")
  return ModifierTable[modifier.stringVal]

proc xorModifiers(modifiers: openarray[TomlValueRef]): int =
  for tomlElement in modifiers:
    result = result or getModifierMask(tomlElement)

proc configureAction*(this: Config, actionName: string, actionInvokee: Action) =
  this.identifierTable[actionName] = actionInvokee

proc configureExternalProcess(this: Config, command: string) =
  this.identifierTable[command] =
    proc(keycode: int) =
      try:
        discard startProcess(command = command, options = { poEvalCommand })
      except:
        echo "Failed to start command: ", command

proc hookConfig*(this: Config, eventManager: XEventManager) =
  let listener: XEventListener = proc(e: TXEvent) =
    let mask: int = cleanMask(int(e.xkey.state))
    let keyCombo: KeyCombo = (int(e.xkey.keycode), mask)
    if this.keyComboTable.hasKey(keyCombo):
      this.keyComboTable[keyCombo](keyCombo.keycode)
  eventManager.addListener(listener, KeyPress)

proc populateControlsTable(this: Config, configTable: TomlTable, display: PDisplay) =
  if not configTable.hasKey("controls"):
    return
  # Populate window manager controls
  let controlsTable = configTable["controls"]
  if controlsTable.kind != TomlValueKind.Table:
    raise newException(Exception, "Invalid config table!")
  for action in controlsTable.tableVal[].keys():
    this.populateControlAction(display, action, controlsTable[action].tableVal[])

proc populateExternalProcessSettings(this: Config, configTable: TomlTable, display: PDisplay) =
  if not configTable.hasKey("startProcess"):
    return
  # Populate external commands
  let externalProcessesTable = configTable["startProcess"]
  if externalProcessesTable.kind != TomlValueKind.Array:
    echo "No \"startProcess\" commands defined!"
  else:
    for commandDeclaration in externalProcessesTable.arrayVal:
      if commandDeclaration.kind != TomlValueKind.Table:
        echo "Invalid \"startProcess\" configuration command!"
        continue
      if not commandDeclaration.tableVal[].hasKey("command"):
        echo "Invalid \"startProcess\" configuration: Missing\"command\" string!"
        continue
      let command = commandDeclaration.tableVal["command"].stringVal
      this.configureExternalProcess(command)
      this.populateControlAction(
        display,
        command,
        commandDeclaration.tableVal[]
      )

proc populateGeneralSettings*(this: Config, configTable: TomlTable) =
  if not configTable.hasKey("settings"):
    return
  let settingsTable = configTable["settings"]
  if settingsTable.kind != TomlValueKind.Table:
    echo "Invalid settings table! Using default settings"
    return
  if settingsTable.hasKey("gapSize"):
    let gapSizeSetting = settingsTable["gapSize"]
    if gapSizeSetting.kind == TomlValueKind.Int:
      this.gapSize = max(0, gapSizeSetting.intVal).uint
    else:
      echo "gapSize is not an integer value!"

proc populateKeyComboTable*(this: Config, configTable: TomlTable, display: PDisplay) =
  ## Reads the user's configuration file and set the keybindings.
  this.populateControlsTable(configTable, display)
  this.populateExternalProcessSettings(configTable, display)

proc findConfigPath(): string =
  let configHome = os.getConfigDir()
  result = configHome & "nimdow/config.toml"
  if not fileExists(result):
    raise newException(Exception, result & " does not exist")

proc loadConfigFile*(): TomlTable =
  ## Reads the user's configuration file into a table.
  let configPath = findConfigPath()
  let loadedConfig = parsetoml.parseFile(configPath)
  if loadedConfig.kind != TomlValueKind.Table:
    raise newException(Exception, "Invalid config file!")
  return loadedConfig.tableVal[]

proc populateControlAction(this: Config, display: PDisplay, action: string, configTable: TomlTable) =
  let keyCombos = this.getKeyCombos(configTable, display, action)
  for keyCombo in keyCombos:
    if this.identifierTable.hasKey(action):
      this.keyComboTable[keyCombo] = this.identifierTable[action]
    else:
      echo "Invalid key config action: \"", action, "\" does not exist"

proc getKeyCombos(this: Config, configTable: TomlTable, display: PDisplay, action: string): seq[KeyCombo] =
  ## Gets the KeyCombos associated with the given `action` from the table.
  let modifierArray = this.getModifiersForAction(configTable, action)
  let modifiers: int = xorModifiers(modifierArray)
  let keys: seq[string] = this.getKeysForAction(configTable, action)
  for key in keys:
    let keycode: int = key.toKeycode(display)
    result.add((keycode, modifiers))

proc getKeysForAction(this: Config, configTable: TomlTable, action: string): seq[string] =
  var tomlKeys = configTable["keys"]
  if tomlKeys.kind != TomlValueKind.Array:
    raise newException(Exception, "Invalid key config for action: " & action &
                       "\n\"keys\" must be an array of strings")
  for tomlKey in tomlKeys.arrayVal:
    if tomlKey.kind != TomlValueKind.String:
      raise newException(Exception, "Invalid key configuration: " &
                         repr(tomlKey) & " is not a string")
    result.add(tomlKey.stringVal)

proc getModifiersForAction(this: Config, configTable: TomlTable, action: string): seq[TomlValueRef] =
  var modifiersConfig = configTable["modifiers"]
  if modifiersConfig.kind != TomlValueKind.Array:
    raise newException(Exception, "Invalid key configuration: " &
                       repr(modifiersConfig) & " is not an array")
  return modifiersConfig.arrayVal

