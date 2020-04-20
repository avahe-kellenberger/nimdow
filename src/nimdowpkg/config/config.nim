import 
  "../keys/keyutils",
  parsetoml,
  tables,
  x11 / xlib

type KeyCombo* =
  tuple[keycode: int, modifiers: int] 

# TODO: value of this table should be "proc".
# Need to find a way to map a string repr of a proc to the proc itself.
var ConfigTable* = tables.initTable[KeyCombo, string]()

func xorModifiers(modifiers: openarray[TomlValueRef]): int =
  # TODO: OR all the values together (and ensure they are ints)
  1

proc getKeyCombo(loadedConfig: TomlTable, display: PDisplay, action: string): KeyCombo =
  var keyConfig = loadedConfig[action]["key"]
  var modifiersConfig = loadedConfig[action]["modifiers"]
  block validation:
    if modifiersConfig.kind != TomlValueKind.Array or
       keyConfig.kind != TomlValueKind.String:
      raise newException(Exception, "Invalid key configuration!")

  let modifierArray = modifiersConfig.arrayVal
  let modifiers: int = xorModifiers(modifierArray)
  let keycode: int = keyConfig.stringVal.toKeycode(display)
  return (keycode, modifiers)

proc populateAction(display: PDisplay, action: string, loadedConfig: TomlTable) =
  let keyCombo = loadedConfig.getKeyCombo(display, action)
  ConfigTable[keyCombo] = action

proc loadConfigfile(configPath: string): TomlTable =
  ## Reads the user's configuration file into a table.
  let loadedConfig = parsetoml.parseFile(configPath)
  if loadedConfig.kind != TomlValueKind.Table:
    raise newException(Exception, "Invalid key configuration!")
  return loadedConfig.tableVal[]

proc populateConfigTable*(display: PDisplay, configPath: string) =
  ## Reads the user's configuration file and set the keybindings.
  let configTable = loadConfigfile(configPath)
  display.populateAction("testAction", configTable)
  display.populateAction("testAction2", configTable)

