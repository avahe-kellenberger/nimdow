import 
  x11 / [x,  xlib],
  parsetoml,
  tables,
  "../keys/keyutils",
  "../event/xeventmanager"

type
  KeyCombo* = tuple[keycode: int, modifiers: int]
  WindowAction* = proc()

# Mapping of config keys to functions.
var ProcTable = initTable[string, WindowAction]()
var ConfigTable* = initTable[KeyCombo, WindowAction]()

proc configureAction*(actionName: string, actionInvokee: WindowAction)
proc hookConfig*(eventManager: XEventManager)
proc populateConfigTable*(display: PDisplay)
proc findConfigPath(): string
proc loadConfigfile(configPath: string): TomlTable
proc populateAction(display: PDisplay, action: string, configTable: TomlTable)
proc getKeyCombo(configTable: TomlTable, display: PDisplay, action: string): KeyCombo
proc getKeyForAction(configTable: TomlTable, action: string): string
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
      ConfigTable[keyCombo]()
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
  let keyCombo = configTable.getKeyCombo(display, action)
  if not ProcTable.hasKey(action):
    raise newException(Exception, "Invalid key configuration: " &
                       repr(action) & " not found")
  ConfigTable[keyCombo] = ProcTable[action]

proc getKeyCombo(configTable: TomlTable, display: PDisplay, action: string): KeyCombo =
  ## Gets the KeyCombo associated with the given `action` from the table.
  let key: string = configTable.getKeyForAction(action)
  let modifierArray = configTable.getModifiersForAction(action)
  let modifiers: int = xorModifiers(modifierArray)
  let keycode: int = key.toKeycode(display)
  return (keycode, modifiers)

proc getKeyForAction(configTable: TomlTable, action: string): string =
  var keyConfig = configTable[action]["key"]
  if keyConfig.kind != TomlValueKind.String:
    raise newException(Exception, "Invalid key configuration: " &
                       repr(keyConfig) & " is not a string")
  return keyConfig.stringVal

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

