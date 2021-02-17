import
  parsetoml,
  strutils

import
  ../tag

const tableName = "monitors"

type
  TagSettings* = OrderedTable[TagID, TagSetting]

proc createDefaultTagSettings*(tagCount: Positive): TagSettings =
  for i in 1..tagCount:
    result[i] = TagSetting(displayString: $i)

proc populateTagSettings*(tagSettingsTable: TomlTableRef): TagSettings =
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
    var currentTagSettings: TagSetting = result[tagID]

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
      currentTagSettings.numMasterWindows = numMasterWindows.intVal

