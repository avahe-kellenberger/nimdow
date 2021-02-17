const tagCount* = 9

type
  TagID* = 1..tagCount
  TagSetting* = ref object
    displayString*: string
    numMasterWindows*: int

