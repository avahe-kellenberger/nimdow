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

# Mapping of config keys to functions.
var IdentifierTable = initTable[string, Action]()
var KeyComboTable* = initTable[KeyCombo, Action]()

proc configureAction*(actionName: string, actionInvokee: Action)
proc hookConfig*(eventManager: XEventManager)
proc populateKeyComboTable*(display: PDisplay)
proc findConfigPath(): string
proc loadConfigfile(configPath: string): TomlTable
proc populateControlAction(display: PDisplay, action: string, configTable: TomlTable)
proc getKeyCombos(configTable: TomlTable, display: PDisplay, action: string): seq[KeyCombo]
proc getKeysForAction(configTable: TomlTable, action: string): seq[string]
proc getModifiersForAction(configTable: TomlTable, action: string): seq[TomlValueRef]
proc xorModifiers(modifiers: openarray[TomlValueRef]): int
proc getModifierMask(modifier: TomlValueRef): int

proc configureAction*(actionName: string, actionInvokee: Action) =
  IdentifierTable[actionName] = actionInvokee

proc configureExternalProcess(command: string) =
  IdentifierTable[command] =
    proc(keycode: int) =
      var process: Process
      try:
        process = startProcess(command = command, options = { poEvalCommand })
      except:
        echo "Failed to start command: ", command

proc hookConfig*(eventManager: XEventManager) =
  let listener: XEventListener = proc(e: TXEvent) =
    let mask: int = cleanMask(int(e.xkey.state))
    let keyCombo: KeyCombo = (int(e.xkey.keycode), mask)
    if KeyComboTable.hasKey(keyCombo):
      KeyComboTable[keyCombo](keyCombo.keycode)
  eventManager.addListener(listener, KeyPress)

proc populateKeyComboTable*(display: PDisplay) =
  ## Reads the user's configuration file and set the keybindings.
  let configPath = findConfigPath()
  let configTable = loadConfigfile(configPath)
  # Populate window manager controls
  let controlsTable = configTable["controls"]
  if controlsTable.kind != TomlValueKind.Table:
    raise newException(Exception, "Invalid config table!")
  for action in controlsTable.tableVal[].keys():
    display.populateControlAction(action, controlsTable[action].tableVal[])

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
      configureExternalProcess(command)
      display.populateControlAction(
        command,
        commandDeclaration.tableVal[]
      )

proc findConfigPath(): string =
  let configHome = os.getConfigDir()
  result = configHome & "nimdow/config.toml"
  if not fileExists(result):
    raise newException(Exception, result & " does not exist")

proc loadConfigfile(configPath: string): TomlTable =
  ## Reads the user's configuration file into a table.
  let loadedConfig = parsetoml.parseFile(configPath)
  if loadedConfig.kind != TomlValueKind.Table:
    raise newException(Exception, "Invalid config file!")
  return loadedConfig.tableVal[]

proc populateControlAction(display: PDisplay, action: string, configTable: TomlTable) =
  let keyCombos = configTable.getKeyCombos(display, action)
  for keyCombo in keyCombos:
    if IdentifierTable.hasKey(action):
      KeyComboTable[keyCombo] = IdentifierTable[action]
    else:
      echo "Invalid key config action: \"", action, "\" does not exist"

proc getKeyCombos(configTable: TomlTable, display: PDisplay, action: string): seq[KeyCombo] =
  ## Gets the KeyCombos associated with the given `action` from the table.
  let modifierArray = configTable.getModifiersForAction(action)
  let modifiers: int = xorModifiers(modifierArray)
  let keys: seq[string] = configTable.getKeysForAction(action)
  for key in keys:
    let keycode: int = key.toKeycode(display)
    result.add((keycode, modifiers))

proc getKeysForAction(configTable: TomlTable, action: string): seq[string] =
  var tomlKeys = configTable["keys"]
  if tomlKeys.kind != TomlValueKind.Array:
    raise newException(Exception, "Invalid key config for action: " & action &
                       "\n\"keys\" must be an array of strings")
  for tomlKey in tomlKeys.arrayVal:
    if tomlKey.kind != TomlValueKind.String:
      raise newException(Exception, "Invalid key configuration: " &
                         repr(tomlKey) & " is not a string")
    result.add(tomlKey.stringVal)

proc getModifiersForAction(configTable: TomlTable, action: string): seq[TomlValueRef] =
  var modifiersConfig = configTable["modifiers"]
  if modifiersConfig.kind != TomlValueKind.Array:
    raise newException(Exception, "Invalid key configuration: " &
                       repr(modifiersConfig) & " is not an array")
  return modifiersConfig.arrayVal

proc xorModifiers(modifiers: openarray[TomlValueRef]): int =
  for tomlElement in modifiers:
    result = result or getModifierMask(tomlElement)

proc getModifierMask(modifier: TomlValueRef): int =
  if modifier.kind != TomlValueKind.String:
    raise newException(Exception, "Invalid key configuration: " &
                       repr(modifier) & " is not a string")
  if not ModifierTable.hasKey(modifier.stringVal):
    raise newException(Exception, "Invalid key configuration: " &
                       repr(modifier) & " is not a a valid key modifier")
  return ModifierTable[modifier.stringVal]

