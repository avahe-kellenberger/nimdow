import
  parsetoml,
  strutils

import
  ../tag

type
  TagSettings* = OrderedTable[TagID, TagSetting]

proc createDefaultTagSettings*(): TagSettings =
  for i in 1..tagCount:
    result[i] = newTagSetting($i, 1)

proc createUniformTagSettings*(displayString: string, numMasterWindows: Positive): TagSettings =
  for i in 1..tagCount:
    result[i] = newTagSetting(displayString, numMasterWindows)

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

proc populateTagSettings*(settings: var TagSettings, tagSettingsTable: TomlTableRef) =
  var allTagSettings: TagSetting = nil

  if tagSettingsTable.hasKey("all"):
    let allTagSettingsTable = tagSettingsTable["all"]
    if allTagSettingsTable.kind != TomlValueKind.Table:
      raise newException(Exception, "Settings table incorrect type for tag ID: all")
    allTagSettings = newTagSetting("", 9999)
    allTagSettings.parseTagSetting(allTagSettingsTable.tableVal)

    for setting in settings.mvalues:
      setting = deepCopy allTagSettings

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

