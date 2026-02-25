import
  options,
  strutils

export options

import layout, masterstacklayout

proc parseLayoutSetting*(command: string): Option[LayoutSettings] =
  case command.toLower:
  of "masterstack":
    some(MasterStackLayoutSettings().LayoutSettings())
  else:
    none[LayoutSettings]()
