import 
  x11 / [x,  xlib],
  parsetoml,
  tables,
  "../keys/keyutils",
  "../event/xeventmanager"

type
  KeyCombo* = tuple[keycode: int, modifiers: int]
  WindowAction* = proc(keycode: int): void

# Mapping of config keys to functions.
var ProcTable = initTable[string, WindowAction]()
var ConfigTable* = initTable[KeyCombo, WindowAction]()

proc configureAction*(actionName: string, actionInvokee: WindowAction)
proc hookConfig*(eventManager: XEventManager)
proc populateConfigTable*(display: PDisplay)
proc findConfigPath(): string
proc loadConfigfile(configPath: string): TomlTable
proc populateAction(display: PDisplay, action: string, configTable: TomlTable)
proc getKeyCombos(configTable: TomlTable, display: PDisplay, action: string): seq[KeyCombo]
proc getKeysForAction(configTable: TomlTable, action: string): seq[string]
proc getModifiersForAction(configTable: TomlTable, action: string): seq[TomlValueRef]
proc xorModifiers(modifiers: openarray[TomlValueRef]): int
proc getModifierMask(modifier: TomlValueRef): int

proc configureAction*(actionName: string, actionInvokee: WindowAction) =
  ProcTable[actionName] = actionInvokee

proc hookConfig*(eventManager: XEventManager) =
  let listener: XEventListener = proc(e: TXEvent) =
    let mask: int = cleanMask(int(e.xkey.state))
    let keyCombo: KeyCombo = (int(e.xkey.keycode), mask)
    if ConfigTable.hasKey(keyCombo):
      ConfigTable[keyCombo](keyCombo.keycode)
  eventManager.addListener(listener, KeyPress)

proc populateConfigTable*(display: PDisplay) =
  ## Reads the user's configuration file and set the keybindings.
  let configPath = findConfigPath()
  let configTable = loadConfigfile(configPath)
  for action in configTable.keys():
    display.populateAction(action, configTable)

proc findConfigPath(): string =
  # TODO: find this path dynamically
  return "config.default.toml"

proc loadConfigfile(configPath: string): TomlTable =
  ## Reads the user's configuration file into a table.
  let loadedConfig = parsetoml.parseFile(configPath)
  if loadedConfig.kind != TomlValueKind.Table:
    raise newException(Exception, "Invalid key configuration!")
  return loadedConfig.tableVal[]

proc populateAction(display: PDisplay, action: string, configTable: TomlTable) =
  let keyCombos = configTable.getKeyCombos(display, action)
  for keyCombo in keyCombos:
    if ProcTable.hasKey(action):
      ConfigTable[keyCombo] = ProcTable[action]
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
  var tomlKeys = configTable[action]["keys"]
  if tomlKeys.kind != TomlValueKind.Array:
    raise newException(Exception, "Invalid key config for action: " & action &
                       "\n\"keys\" must be an array of strings")

  for tomlKey in tomlKeys.arrayVal:
    if tomlKey.kind != TomlValueKind.String:
      raise newException(Exception, "Invalid key configuration: " &
                         repr(tomlKey) & " is not a string")
    result.add(tomlKey.stringVal)

proc getModifiersForAction(configTable: TomlTable, action: string): seq[TomlValueRef] =
  var modifiersConfig = configTable[action]["modifiers"]
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

