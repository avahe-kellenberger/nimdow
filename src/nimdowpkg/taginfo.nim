const tagCount* = 9

type
  TagID* = 1..tagCount
  TagSetting* = ref object
    displayString*: string
    numMasterWindows*: Positive
    defaultMasterWidthPercentage*: int

proc newTagSetting*(displayString: string, numMasterWindows: Positive, defaultMasterWidthPercentage :int): TagSetting =
  TagSetting(displayString: displayString, numMasterWindows: numMasterWindows, defaultMasterWidthPercentage: defaultMasterWidthPercentage)

