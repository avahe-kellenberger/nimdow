const tagCount* = 9

type
  TagID* = 1..tagCount
  TagSetting* = ref object
    keycode*: int
    modifiers*: int
    totalModifiers*: int
    displayString*: string

