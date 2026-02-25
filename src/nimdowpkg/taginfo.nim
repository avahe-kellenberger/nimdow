import layouts/layoutsettings

const tagCount* = 9

type
  TagID* = 1..tagCount
  TagSetting* = ref object
    displayString*: string
    layoutSettings*: LayoutSettings

proc newTagSetting*(displayString: string): TagSetting =
  TagSetting(displayString: displayString)

