import
  options,
  strutils

export options

import layout, masterstacklayout, pimo

proc parseLayoutSetting*(command: string): Option[LayoutSettings] =
  case command.toLower:
  of "masterstack":
    some(MasterStackLayoutSettings().LayoutSettings())
  of "pimo":
    some(PimoLayoutSettings().LayoutSettings())
  else:
    none[LayoutSettings]()
