import
  os,
  osproc,
  parsetoml,
  strutils,
  tables,
  x11 / [x,  xlib],
  "../keys/keyutils",
  "../event/xeventmanager",
  "../logger",
  "../tag"

var configLoc*: string

proc findConfigPath*(): string =
  let configHome = os.getConfigDir()
  result = configHome & "nimdow/config.toml"
  if not fileExists(result):
    result = "/usr/share/nimdow/config.default.toml"
  if not fileExists(result):
    log "config file " & result & " does not exist", lvlError
    result = ""

type
  KeyCombo* = tuple[keycode: int, modifiers: int]
  Action* = proc(keyCombo: KeyCombo): void
  WindowSettings* = ref object
    gapSize*: uint
    tagCount*: uint
    borderColorUnfocused*: int
    borderColorFocused*: int
    borderColorUrgent*: int
    borderWidth*: uint
  BarSettings* = ref object
    height*: uint
    fonts*: seq[string]
    # Hex values
    fgColor*, bgColor*, selectionColor*, urgentColor*: int
  Config* = ref object
    eventManager: XEventManager
    identifierTable*: Table[string, Action]
    keyComboTable*: Table[KeyCombo, Action]
    windowSettings*: WindowSettings
    barSettings*: BarSettings
    listener*: XEventListener
    loggingEnabled*: bool
    tagSettings*: OrderedTable[TagID, TagSetting]

proc newConfig*(eventManager: XEventManager): Config =
  Config(
    eventManager: eventManager,
    identifierTable: initTable[string, Action](),
    keyComboTable: initTable[KeyCombo, Action](),
    windowSettings: WindowSettings(
      gapSize: 12,
      tagCount: 9,
      borderColorUnfocused: 0x1c1b19,
      borderColorFocused: 0x519f50,
      borderColorUrgent: 0xff5555,
      borderWidth: 1
    ),
    barSettings: BarSettings(
      height: 20,
      fonts: @[
        "monospace:size=10:anialias=false",
        "NotoColorEmoji:size=10:anialias=false"
      ],
      fgColor: 0xfce8c3,
      bgColor: 0x1c1b19,
      selectionColor: 0x519f50,
      urgentColor: 0xef2f27
    ),
    loggingEnabled: false
  )

proc configureAction*(this: Config, actionName: string, actionInvokee: Action)
proc hookConfig*(this: Config)
proc populateKeyComboTable*(this: Config, configTable: TomlTable, display: PDisplay)
proc populateControlAction(this: Config, display: PDisplay, action: string, configTable: TomlTable)
proc getKeyCombos(
  this: Config,
  configTable: TomlTable,
  display: PDisplay,
  action: string,
  keys: seq[string]
): seq[KeyCombo]
proc getKeyCombos(
  this: Config,
  configTable: TomlTable,
  display: PDisplay,
  action: string
): seq[KeyCombo]
proc getKeysForAction(this: Config, configTable: TomlTable, action: string): seq[string]
proc getModifiersForAction(this: Config, configTable: TomlTable, action: string): seq[TomlValueRef]
proc getAutostartCommands(this: Config, configTable: TomlTable): seq[string]
proc runCommands(this: Config, commands: varargs[string])

proc runAutostartCommands*(this: Config, configTable: TomlTable) =
  let autostartCommands = this.getAutostartCommands(configTable)
  this.runCommands(autostartCommands)

proc getAutostartCommands(this: Config, configTable: TomlTable): seq[string] =
  if not configTable.hasKey("autostart"):
    return
  let autoStartTable = configTable["autostart"]
  if autoStartTable.kind != TomlValueKind.Table:
    raise newException(Exception,"Invalid autostart table")

  if not autoStartTable.tableVal[].hasKey("exec"):
    raise newException(Exception, "Autostart table does not have exec key")

  for cmd in autoStartTable.tableVal[]["exec"].arrayVal:
    if cmd.kind == TomlValueKind.String:
      result.add(cmd.stringVal)
    else:
      log repr(cmd) & " is not a string", lvlWarn

proc runCommands(this: Config, commands: varargs[string]) =
  for cmd in commands:
    try:
      let process = startProcess(command = cmd, options = { poEvalCommand })
      this.eventManager.submitProcess(process)
    except:
      log "Failed to start command: " & cmd, lvlWarn

proc getModifierMask(modifier: TomlValueRef): int =
  if modifier.kind != TomlValueKind.String:
    log "Invalid key configuration: " & repr(modifier) & " is not a string", lvlError
    return

  if not ModifierTable.hasKey(modifier.stringVal):
    log "Invalid key configuration: " & repr(modifier) & " is not a valid key modifier", lvlError
    return

  return ModifierTable[modifier.stringVal]

proc bitorModifiers(modifiers: openarray[TomlValueRef]): int =
  for tomlElement in modifiers:
    result = result or getModifierMask(tomlElement)

proc configureAction*(this: Config, actionName: string, actionInvokee: Action) =
  this.identifierTable[actionName] = actionInvokee

proc configureExternalProcess(this: Config, command: string) =
  this.identifierTable[command] =
    proc(keyCombo: KeyCombo) =
      this.runCommands(command)

proc hookConfig*(this: Config) =
  this.listener = proc(e: XEvent) =
    let mask: int = cleanMask(int(e.xkey.state))
    let keyCombo: KeyCombo = (int(e.xkey.keycode), mask)
    if this.keyComboTable.hasKey(keyCombo):
      this.keyComboTable[keyCombo](keyCombo)
  this.eventManager.addListener(this.listener, KeyPress)

proc populateDefaultTagSettings(this: Config, display: PDisplay) =
  for i in 1..tagCount:
    this.tagSettings[i] = TagSetting(
      displayString: $i,
      keycode: ($i).toKeycode(display)
    )

proc populateTagSettings(this: Config, configTable: TomlTable, display: PDisplay) =
  this.populateDefaultTagSettings(display)

  if not configTable.hasKey("tags"):
    return

  let tagsTable = configTable["tags"]
  if tagsTable.kind != TomlValueKind.Table:
    raise newException(Exception, "Invalid tags config table")

  for tagIDstr, settingsToml in tagsTable.tableVal.pairs():
    if settingsToml.kind != TomlValueKind.Table:
      log "Settings table incorrect type for tag ID: " & tagIDstr
      continue

    # Parse the tag ID.
    var tagID: int
    try:
      tagID = parseInt(tagIDstr)
    except:
      log "Invalid tag id: " & tagIDstr
      continue

    let currentTagSettingsTable = settingsToml.tableVal
    var currentTagSettings: TagSetting = this.tagSettings[tagID]

    if currentTagSettingsTable.hasKey("displayString"):
      let displayString = currentTagSettingsTable["displayString"]
      if displayString.kind == TomlValueKind.String:
        currentTagSettings.displayString = displayString.stringVal

    if currentTagSettingsTable.hasKey("key"):
      let keyString = currentTagSettingsTable["key"]
      if keyString.kind == TomlValueKind.String:
        currentTagSettings.keycode = keyString.stringVal.toKeycode(display)

proc populateControlsTable(this: Config, configTable: TomlTable, display: PDisplay) =
  if not configTable.hasKey("controls"):
    return
  # Populate window manager controls
  let controlsTable = configTable["controls"]
  if controlsTable.kind != TomlValueKind.Table:
    raise newException(Exception, "Invalid controls config table")

  for action in controlsTable.tableVal.keys():
    this.populateControlAction(display, action, controlsTable[action].tableVal[])

proc populateTagControlAction(
  this: Config,
  display: PDisplay,
  action: string,
  configTable: TomlTableRef,
  tagSetting: var TagSetting
) =
  if not this.identifierTable.hasKey(action):
    raise newException(Exception, "Invalid key config action: \"" & action & "\" does not exist")

  let
    modifierArray = this.getModifiersForAction(configTable[], action)
    modifiers: int = bitorModifiers(modifierArray)
    keyCombo = (tagSetting.keycode, modifiers)

  this.keyComboTable[keyCombo] = this.identifierTable[action]

proc populateTagControlsTable*(this: Config, configTable: TomlTable, display: PDisplay) =
  if not configTable.hasKey("tagcontrols"):
    return

  # Populate tag controls
  let controlsTable = configTable["tagcontrols"]
  if controlsTable.kind != TomlValueKind.Table:
    raise newException(Exception, "Invalid tagcontrols table")

  for tagSetting in this.tagSettings.mvalues():
    for action, table in controlsTable.tableVal.pairs():
      if table.kind == TomlValueKind.Table:
        this.populateTagControlAction(display, action, table.tableVal, tagSetting)

proc populateExternalProcessSettings(this: Config, configTable: TomlTable, display: PDisplay) =
  if not configTable.hasKey("startProcess"):
    return

  # Populate external commands
  let externalProcessesTable = configTable["startProcess"]

  if externalProcessesTable.kind != TomlValueKind.Array:
    raise newException(Exception, "No \"startProcess\" commands defined!")

  for commandDeclaration in externalProcessesTable.arrayVal:
    if commandDeclaration.kind != TomlValueKind.Table:
      raise newException(Exception, "Invalid \"startProcess\" configuration command!")
    if not commandDeclaration.tableVal[].hasKey("command"):
      raise newException(Exception, "Invalid \"startProcess\" configuration: Missing \"command\" string!")

    let command = commandDeclaration.tableVal["command"].stringVal
    this.configureExternalProcess(command)
    this.populateControlAction(
      display,
      command,
      commandDeclaration.tableVal[]
    )

proc loadHexValue(this: Config, settingsTable: TomlTableRef, valueName: string): int =
  if settingsTable.hasKey(valueName):
    let setting = settingsTable[valueName]
    if setting.kind == TomlValueKind.String:
      return fromHex[int](setting.stringVal)
    else:
      raise newException(Exception, valueName & " is not a proper hex value! Ensure it is wrapped in double quotes")
  return -1

proc populateBarSettings*(this: Config, settingsTable: TomlTableRef) =
  let bgColor = this.loadHexValue(settingsTable, "barBackgroundColor")
  if bgColor != -1:
    this.barSettings.bgColor = bgColor

  let fgColor = this.loadHexValue(settingsTable, "barForegroundColor")
  if fgColor != -1:
    this.barSettings.fgColor = fgColor

  let selectionColor = this.loadHexValue(settingsTable, "barSelectionColor")
  if selectionColor != -1:
    this.barSettings.selectionColor = selectionColor

  let urgentColor = this.loadHexValue(settingsTable, "barUrgentColor")
  if urgentColor != -1:
    this.barSettings.urgentColor = urgentColor

  if settingsTable.hasKey("barHeight"):
    let barHeight = settingsTable["barHeight"]
    if barHeight.kind == TomlValueKind.Int:
      this.barSettings.height = max(0, barHeight.intVal).uint

  if settingsTable.hasKey("barFonts"):
    let barFonts = settingsTable["barFonts"]
    if barFonts.kind != TomlValueKind.Array:
      raise newException(Exception, "barFonts is not an array of strings!")

    var fonts: seq[string]
    for font in barFonts.arrayVal:
      if font.kind == TomlValueKind.String:
        fonts.add(font.stringVal)
      else:
        raise newException(Exception, "Invalid font - must be a string!")
    this.barSettings.fonts = fonts

proc populateGeneralSettings*(this: Config, configTable: TomlTable) =
  if not configTable.hasKey("settings") or configTable["settings"].kind != TomlValueKind.Table:
    raise newException(Exception, "Invalid settings table")

  let settingsTable = configTable["settings"].tableVal

  # Window settings
  if settingsTable.hasKey("gapSize"):
    let gapSizeSetting = settingsTable["gapSize"]
    if gapSizeSetting.kind == TomlValueKind.Int:
      this.windowSettings.gapSize = max(0, gapSizeSetting.intVal).uint
    else:
      log "gapSize is not an integer value!", lvlWarn

  if settingsTable.hasKey("borderWidth"):
    let borderWidthSetting = settingsTable["borderWidth"]
    if borderWidthSetting.kind == TomlValueKind.Int:
      this.windowSettings.borderWidth = max(0, borderWidthSetting.intVal).uint
    else:
      log "borderWidth is not an integer value!", lvlWarn

  let unfocusedBorderVal = this.loadHexValue(settingsTable, "borderColorUnfocused")
  if unfocusedBorderVal != -1:
    this.windowSettings.borderColorUnfocused = unfocusedBorderVal

  let focusedBorderVal = this.loadHexValue(settingsTable, "borderColorFocused")
  if focusedBorderVal != -1:
    this.windowSettings.borderColorFocused = focusedBorderVal

  let urgentBorderVal = this.loadHexValue(settingsTable, "borderColorUrgent")
  if urgentBorderVal != -1:
    this.windowSettings.borderColorUrgent = urgentBorderVal

  # Bar settings
  this.populateBarSettings(settingsTable)

  # General settings
  if settingsTable.hasKey("loggingEnabled"):
    let loggingEnabledSetting = settingsTable["loggingEnabled"]
    if loggingEnabledSetting.kind == TomlValueKind.Bool:
      this.loggingEnabled = loggingEnabledSetting.boolVal
    else:
      raise newException(Exception, "loggingEnabled is not true/false!")

proc populateKeyComboTable*(this: Config, configTable: TomlTable, display: PDisplay) =
  ## Reads the user's configuration file and set the keybindings.
  this.populateControlsTable(configTable, display)
  this.populateTagSettings(configTable, display)
  this.populateTagControlsTable(configTable, display)
  this.populateExternalProcessSettings(configTable, display)

proc loadConfigFile*(): TomlTable =
  ## Reads the user's configuration file into a table.
  ## Set configLoc before calling this procedure,
  ## if you would like to use an alternate config file.
  if configLoc.len == 0:
    configLoc = findConfigPath()
  let loadedConfig = parsetoml.parseFile(configLoc)
  if loadedConfig.kind != TomlValueKind.Table:
    raise newException(Exception, "Invalid config file!")
  return loadedConfig.tableVal[]

proc populateControlAction(this: Config, display: PDisplay, action: string, configTable: TomlTable) =
  let keyCombos = this.getKeyCombos(configTable, display, action)
  for keyCombo in keyCombos:
    if this.identifierTable.hasKey(action):
      this.keyComboTable[keyCombo] = this.identifierTable[action]
    else:
      raise newException(Exception, "Invalid key config action: \"" & action & "\" does not exist")

proc getKeyCombos(
  this: Config,
  configTable: TomlTable,
  display: PDisplay,
  action: string,
  keys: seq[string]
): seq[KeyCombo] =
  ## Gets the KeyCombos associated with the given `action` from the table.
  let modifierArray = this.getModifiersForAction(configTable, action)
  let modifiers: int = bitorModifiers(modifierArray)
  for key in keys:
    let keycode = key.toKeycode(display)
    result.add((keycode, cleanMask(modifiers)))

proc getKeyCombos(
  this: Config,
  configTable: TomlTable,
  display: PDisplay,
  action: string
): seq[KeyCombo] =
  return this.getKeyCombos(
    configTable,
    display,
    action,
    this.getKeysForAction(configTable, action)
  )

proc getKeysForAction(this: Config, configTable: TomlTable, action: string): seq[string] =
  if not configTable.hasKey("keys"):
    log "\"keys\" not found in config table for action \"" & action & "\"", lvlError
    return
  var tomlKeys = configTable["keys"]
  if tomlKeys.kind != TomlValueKind.Array:
    log "Invalid key config for action: " & action & "\n\"keys\" must be an array of strings", lvlError
    return

  for tomlKey in tomlKeys.arrayVal:
    if tomlKey.kind != TomlValueKind.String:
      log "Invalid key configuration: " & repr(tomlKey) & " is not a string", lvlError
      return
    result.add(tomlKey.stringVal)

proc getModifiersForAction(this: Config, configTable: TomlTable, action: string): seq[TomlValueRef] =
  if configTable.hasKey("modifiers"):
    var modifiersConfig = configTable["modifiers"]
    if modifiersConfig.kind != TomlValueKind.Array:
      log "Invalid key configuration: " & repr(modifiersConfig) & " is not an array", lvlError
    return modifiersConfig.arrayVal

