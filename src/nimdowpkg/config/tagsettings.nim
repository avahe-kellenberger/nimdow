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

proc parseTagSetting(settingsTable: TomlTable): TagSetting =
  # Check for displayString
  if settingsTable.hasKey("displayString"):
    let displayString = settingsTable["displayString"]
    if displayString.kind != TomlValueKind.String:
      raise newException(Exception, "Invalid displayString for tag")
    result.displayString = displayString.stringVal

  # Check for numMasterWindows
  if settingsTable.hasKey("numMasterWindows"):
    let numMasterWindows = settingsTable["numMasterWindows"]
    if numMasterWindows.kind != TomlValueKind.Int:
      raise newException(Exception, "Invalid numMasterWindows for tag")
    result.numMasterWindows = numMasterWindows.intVal.int

proc populateTagSettings*(settings: var TagSettings, tagSettingsTable: TomlTableRef) =
  for tagIDstr, settingsToml in tagSettingsTable.pairs():
    if settingsToml.kind != TomlValueKind.Table:
      raise newException(Exception, "Settings table incorrect type for tag ID: " & tagIDstr)

    # Parse the tag ID.
    var tagID: int
    try:
      tagID = parseInt(tagIDstr)
    except:
      raise newException(Exception, "Invalid tag id: " & tagIDstr)

    let currentTagSettingsTable = settingsToml.tableVal
    var currentTagSettings: TagSetting = settings[tagID]

    # Check for displayString
    if currentTagSettingsTable.hasKey("displayString"):
      let displayString = currentTagSettingsTable["displayString"]
      if displayString.kind != TomlValueKind.String:
        raise newException(Exception, "Invalid displayString for tag: " & tagIDstr)
      currentTagSettings.displayString = displayString.stringVal

    # Check for numMasterWindows
    if currentTagSettingsTable.hasKey("numMasterWindows"):
      let numMasterWindows = currentTagSettingsTable["numMasterWindows"]
      if numMasterWindows.kind != TomlValueKind.Int:
        raise newException(Exception, "Invalid numMasterWindows for tag: " & tagIDstr)
      currentTagSettings.numMasterWindows = numMasterWindows.intVal.int

