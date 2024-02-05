import
  parsetoml,
  strutils

import
  ../tag,
  ../logger,
  ../layouts/layoutsettings

type
  TagSettings* = OrderedTable[TagID, TagSetting]

proc createDefaultTagSettings*(): TagSettings =
  for i in 1..tagCount:
    result[i] = newTagSetting($i, 1, 50)

proc createUniformTagSettings*(displayString: string, numMasterWindows: Positive, defaultMasterWidthPercentage: int): TagSettings =
  for i in 1..tagCount:
    result[i] = newTagSetting(displayString, numMasterWindows, defaultMasterWidthPercentage)

proc parseTagSetting(tagSetting: var TagSetting, settingsTable: TomlTableRef) =
  # Check for displayString
  if settingsTable.hasKey("displayString"):
    let displayString = settingsTable["displayString"]
    if displayString.kind != TomlValueKind.String:
      raise newException(Exception, "Invalid displayString for tag")
    tagSetting.displayString = displayString.stringVal

  # Check for numMasterWindows
  if settingsTable.hasKey("numMasterWindows"):
    let numMasterWindows = settingsTable["numMasterWindows"]
    if numMasterWindows.kind != TomlValueKind.Int:
      raise newException(Exception, "Invalid numMasterWindows for tag")
    tagSetting.numMasterWindows = numMasterWindows.intVal.int

  if settingsTable.hasKey("defaultMasterWidthPercentage"):
    let masterWidthSetting = settingsTable["defaultMasterWidthPercentage"]
    if masterWidthSetting.kind == TomlValueKind.Int:
      tagSetting.defaultMasterWidthPercentage = masterWidthSetting.intVal.int.clamp(10,90)
      if tagSetting.defaultMasterWidthPercentage != masterWidthSetting.intVal:
        log "Invalid defaultMasterWidthPercentage, clamped to 10-90%", lvlWarn
    else:
      raise newException(Exception, "invalid defaultMasterWidthPercentage for tag")

  tagSetting.layoutSettings.populateLayoutSettings(settingsTable)

proc populateTagSettings*(settings: var TagSettings, tagSettingsTable: TomlTableRef) =
  if tagSettingsTable.hasKey("all"):
    let allTagSettingsTable = tagSettingsTable["all"]
    if allTagSettingsTable.kind != TomlValueKind.Table:
      raise newException(Exception, "Settings table incorrect type for tag ID: all")
    var allTagSettings = newTagSetting("", int.high, 50)
    allTagSettings.parseTagSetting(allTagSettingsTable.tableVal)

    for setting in settings.mvalues:
      if allTagSettings.displayString.len > 0:
        setting.displayString = allTagSettings.displayString
      if allTagSettings.numMasterWindows != int.high:
        setting.numMasterWindows = allTagSettings.numMasterWindows
      if allTagSettings.defaultMasterWidthPercentage != 50:
        setting.defaultMasterWidthPercentage = allTagSettings.defaultMasterWidthPercentage

  for tagIDstr, settingsToml in tagSettingsTable.pairs():
    if settingsToml.kind != TomlValueKind.Table:
      raise newException(Exception, "Settings table incorrect type for tag ID: " & tagIDstr)

    # Special case ignored.
    if tagIDstr == "all":
      continue

    # Parse the tag ID.
    var tagID: int
    try:
      tagID = parseInt(tagIDstr)
    except:
      raise newException(Exception, "Invalid tag id: " & tagIDstr)

    let currentTagSettingsTable = settingsToml.tableVal
    var currentTagSettings: TagSetting = settings[tagID]
    currentTagSettings.parseTagSetting(currentTagSettingsTable)

