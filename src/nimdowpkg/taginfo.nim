const tagCount* = 9

type
  TagID* = 1..tagCount
  TagSetting* = ref object
    displayString*: string
    numMasterWindows*: Positive

proc newTagSetting*(displayString: string, numMasterWindows: Positive): TagSetting =
  TagSetting(displayString: displayString, numMasterWindows: numMasterWindows)

