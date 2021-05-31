import
  options,
  strutils

export options

type
  WMCommand* = enum
    wmcReloadConfig = "reloadconfig",
    wmcIncreaseMasterCount = "increasemastercount",
    wmcDecreaseMasterCount = "decreasemastercount",
    wmcMoveWindowToPreviousMonitor = "movewindowtopreviousmonitor",
    wmcMoveWindowToNextMonitor = "movewindowtonextmonitor",
    wmcFocusPreviousMonitor = "focuspreviousmonitor",
    wmcFocusNextMonitor = "focusnextmonitor",
    wmcGoToTag = "gototag",
    wmcGoToPreviousTag = "gotoprevioustag",
    wmcMoveWindowToPreviousTag = "movewindowtoprevioustag",
    wmcToggleTagView = "toggletagview",
    wmcToggleWindowTag = "togglewindowtag",
    wmcFocusNext = "focusnext",
    wmcFocusPrevious = "focusprevious",
    wmcMoveWindowPrevious = "movewindowprevious",
    wmcMoveWindowNext = "movewindownext",
    wmcMoveWindowToTag = "movewindowtotag",
    wmcToggleFullscreen = "togglefullscreen",
    wmcDestroySelectedWindow = "destroyselectedwindow",
    wmcToggleFloating = "togglefloating",
    wmcJumpToUrgentWindow = "jumptourgentwindow"
    wmcIncWidthDiff = "incwidthdiff"
    wmcDecWidthDiff = "decwidthdiff"
    wmcMoveWindowToScratchpad = "movewindowtoscratchpad"
    wmcPopScratchpadLast = "popscratchpadlast"

proc parseCommand*(command: string): Option[WMCommand] =
  try:
    return some(parseEnum[WMCommand](command))
  except:
    return none[WMCommand]()

