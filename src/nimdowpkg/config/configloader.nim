import
  os,
  osproc,
  parsetoml,
  strutils,
  tables,
  x11 / [x,  xlib],
  "../keys/keyutils",
  "../event/xeventmanager",
  "../logger"

var configLoc*: string

proc findConfigPath*(): string =
  let configHome = os.getConfigDir()
  result = configHome & "nimdow/config.toml"
  if not fileExists(result):
    result = "/usr/share/nimdow/config.default.toml"
  if not fileExists(result):
    raise newException(Exception, result & " does not exist")

type
  KeyCombo* = tuple[keycode: int, modifiers: int]
  Action* = proc(keycode: int): void
  WindowSettings* = ref object
    gapSize*: uint
    tagCount*: uint
    borderColorFocused*: int
    borderColorUnfocused*: int
    borderWidth*: uint
  BarSettings* = ref object
    height*: uint
    fonts*: seq[string]
    # Hex values
    fgColor*, bgColor*, selectionColor*: int
  Config* = ref object
    eventManager: XEventManager
    identifierTable*: Table[string, Action]
    keyComboTable*: Table[KeyCombo, Action]
    windowSettings*: WindowSettings
    barSettings*: BarSettings
    listener*: XEventListener
    loggingEnabled*: bool

proc newConfig*(eventManager: XEventManager): Config =
  Config(
    eventManager: eventManager,
    identifierTable: initTable[string, Action](),
    keyComboTable: initTable[KeyCombo, Action](),
    windowSettings: WindowSettings(
      gapSize: 12,
      tagCount: 9,
      borderColorFocused: 0x519f50,
      borderColorUnfocused: 0x1c1b19,
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
      selectionColor: 0x519f50
    ),
    loggingEnabled: false
  )

proc configureAction*(this: Config, actionName: string, actionInvokee: Action)
proc hookConfig*(this: Config)
proc populateKeyComboTable*(this: Config, configTable: TomlTable, display: PDisplay)
proc populateControlAction(this: Config, display: PDisplay, action: string, configTable: TomlTable)
proc getKeyCombos(this: Config, configTable: TomlTable, display: PDisplay, action: string): seq[KeyCombo]
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
    log "Invalid autostart table", lvlWarn
    return
  if not autoStartTable.tableVal[].hasKey("exec"):
    log "Autostart table does not have exec key", lvlWarn
    return
  for cmd in autoStartTable.tableVal[]["exec"].arrayVal:
    if cmd.kind != TomlValueKind.String:
      log repr(cmd) & " is not a string", lvlWarn
    else:
      result.add(cmd.stringVal)

proc runCommands(this: Config, commands: varargs[string]) =
  for cmd in commands:
    try:
      let process = startProcess(command = cmd, options = { poEvalCommand })
      this.eventManager.submitProcess(process)
    except:
      log "Failed to start command: " & cmd, lvlWarn

proc getModifierMask(modifier: TomlValueRef): int =
  if modifier.kind != TomlValueKind.String:
    raise newException(Exception, "Invalid key configuration: " &
                       repr(modifier) & " is not a string")

  if not ModifierTable.hasKey(modifier.stringVal):
    raise newException(Exception, "Invalid key configuration: " &
                       repr(modifier) & " is not a a valid key modifier")

  return ModifierTable[modifier.stringVal]

proc bitorModifiers(modifiers: openarray[TomlValueRef]): int =
  for tomlElement in modifiers:
    result = result or getModifierMask(tomlElement)

proc configureAction*(this: Config, actionName: string, actionInvokee: Action) =
  this.identifierTable[actionName] = actionInvokee

proc configureExternalProcess(this: Config, command: string) =
  this.identifierTable[command] =
    proc(keycode: int) =
      this.runCommands(command)

proc hookConfig*(this: Config) =
  this.listener = proc(e: XEvent) =
    let mask: int = cleanMask(int(e.xkey.state))
    let keyCombo: KeyCombo = (int(e.xkey.keycode), mask)
    if this.keyComboTable.hasKey(keyCombo):
      this.keyComboTable[keyCombo](keyCombo.keycode)
  this.eventManager.addListener(this.listener, KeyPress)

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
    log "No \"startProcess\" commands defined!", lvlWarn
  else:
    for commandDeclaration in externalProcessesTable.arrayVal:
      if commandDeclaration.kind != TomlValueKind.Table:
        log "Invalid \"startProcess\" configuration command!", lvlWarn
        continue
      if not commandDeclaration.tableVal[].hasKey("command"):
        log "Invalid \"startProcess\" configuration: Missing\"command\" string!", lvlWarn
        continue
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
      try:
        return fromHex[int](setting.stringVal)
      except:
        log valueName & " is not a proper hex value! Format: #123456", lvlWarn
    else:
      log valueName & " is not a proper hex value! Ensure it is wrapped in double quotes", lvlWarn
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

  if settingsTable.hasKey("barHeight"):
    let barHeight = settingsTable["barHeight"]
    if barHeight.kind == TomlValueKind.Int:
      this.barSettings.height = max(0, barHeight.intVal).uint

  if settingsTable.hasKey("barFonts"):
    let fonts = settingsTable["barFonts"]
    if fonts.kind != TomlValueKind.Array:
      raise newException(Exception, "barFonts is not an array of strings!")

    if fonts.arrayVal.len > 0:
      # Clear default fonts
      this.barSettings.fonts.setLen(0)

    for font in fonts.arrayVal:
      if font.kind == TomlValueKind.String:
        this.barSettings.fonts.add(font.stringVal)
      else:
        log "Invalid font - must be a string!", lvlWarn

proc populateGeneralSettings*(this: Config, configTable: TomlTable) =
  if not configTable.hasKey("settings") or configTable["settings"].kind != TomlValueKind.Table:
    log "Invalid settings table! Using default settings", lvlWarn
    return

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

  # Bar settings
  this.populateBarSettings(settingsTable)

  # General settings
  if settingsTable.hasKey("loggingEnabled"):
    let loggingEnabledSetting = settingsTable["loggingEnabled"]
    if loggingEnabledSetting.kind == TomlValueKind.Bool:
      this.loggingEnabled = loggingEnabledSetting.boolVal
    else:
      log "loggingEnabled is not true/false!", lvlWarn

proc populateKeyComboTable*(this: Config, configTable: TomlTable, display: PDisplay) =
  ## Reads the user's configuration file and set the keybindings.
  this.populateControlsTable(configTable, display)
  this.populateExternalProcessSettings(configTable, display)

proc loadConfigFile*(): TomlTable =
  ## Reads the user's configuration file into a table.
  ## Set configLoc before calling this procedure,
  ## if you would like to use an alternate config file.
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
      log "Invalid key config action: \"" & action & "\" does not exist", lvlWarn

proc getKeyCombos(this: Config, configTable: TomlTable, display: PDisplay, action: string): seq[KeyCombo] =
  ## Gets the KeyCombos associated with the given `action` from the table.
  let modifierArray = this.getModifiersForAction(configTable, action)
  let modifiers: int = bitorModifiers(modifierArray)
  let keys: seq[string] = this.getKeysForAction(configTable, action)
  for key in keys:
    let keycode: int = key.toKeycode(display)
    result.add((keycode, cleanMask(modifiers)))

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

