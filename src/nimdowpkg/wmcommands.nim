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
    wmcGoToLeftTag = "gotolefttag",
    wmcGoToRightTag = "gotorighttag",
    wmcGoToPreviousTag = "gotoprevioustag",
    wmcMoveWindowToPreviousTag = "movewindowtoprevioustag",
    wmcToggleTagView = "toggletagview",
    wmcToggleWindowTag = "togglewindowtag",
    wmcFocusNext = "focusnext",
    wmcFocusPrevious = "focusprevious",
    wmcMoveWindowPrevious = "movewindowprevious",
    wmcMoveWindowNext = "movewindownext",
    wmcMoveWindowToTag = "movewindowtotag",
    wmcMoveWindowToLeftTag = "movewindowtolefttag",
    wmcMoveWindowToRightTag = "movewindowtorighttag",
    wmcToggleFullscreen = "togglefullscreen",
    wmcDestroySelectedWindow = "destroyselectedwindow",
    wmcToggleFloating = "togglefloating",
    wmcJumpToUrgentWindow = "jumptourgentwindow"
    wmcIncreaseMasterWidth = "increasemasterwidth"
    wmcDecreaseMasterWidth = "decreasemasterwidth"
    wmcMoveWindowToScratchpad = "movewindowtoscratchpad"
    wmcPopScratchpad = "popscratchpad"
    wmcRotateclients = "rotateclients"
    wmcToggleStatusBar = "togglestatusbar"

proc parseCommand*(command: string): Option[WMCommand] =
  try:
    return some(parseEnum[WMCommand](command))
  except CatchableError:
    return none[WMCommand]()

