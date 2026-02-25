import
  parsetoml,
  strutils

import
  ../tag,
  ../layouts/layoutsettings

type
  TagSettings* = OrderedTable[TagID, TagSetting]

proc createDefaultTagSettings*(): TagSettings =
  for i in 1..tagCount:
    result[i] = newTagSetting($i)

proc parseTagSetting(tagSetting: var TagSetting, settingsTable: TomlTableRef) =
  # Check for displayString
  if settingsTable.hasKey("displayString"):
    let displayString = settingsTable["displayString"]
    if displayString.kind != TomlValueKind.String:
      raise newException(Exception, "Invalid displayString for tag")
    tagSetting.displayString = displayString.stringVal

  tagSetting.layoutSettings.populateLayoutSettings(settingsTable)

proc populateTagSettings*(settings: var TagSettings, tagSettingsTable: TomlTableRef) =
  if tagSettingsTable.hasKey("all"):
    let allTagSettingsTable = tagSettingsTable["all"]
    if allTagSettingsTable.kind != TomlValueKind.Table:
      raise newException(Exception, "Settings table incorrect type for tag ID: all")
    for setting in settings.mvalues:
      setting.parseTagSetting(allTagSettingsTable.tableVal)

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

