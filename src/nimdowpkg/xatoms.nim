import
  x11 / [x, xlib]

converter boolToTBool(x: bool): TBool = TBool(x)

type
  WMAtom* = enum
    WMProtocols, WMDalete, WMState, WMTakeFocus, WMLast
  NetAtom* = enum
    NetActiveWindow, NetSupported,
    NetSystemTray, NetSystemTrayOP, NetSystemTrayOrientation, NetSystemTrayOrientationHorz,
    NetWMName, NetWMState, NetWMCheck, NetWMStateFullScreen, NetClientList,
    NetWMWindowType, NetWMWindowTypeNormal, NetWMWindowTypeDialog, NetWMWindowTypeUtility,
    NetWMWindowTypeToolbar, NetWMWindowTypeSplash, NetWMWindowTypeMenu,
    NetWMWindowTypeDropdownMenu, NetWMWindowTypePopupMenu, NetWMWindowTypeTooltip,
    NetWMWindowTypeNotification, NetWMWindowTypeDock, NetLast
  XAtom* = enum
    Manager, Xembed, XembedInfo, XLast

proc getWMAtoms*(display: PDisplay): array[ord(WMLast), TAtom] =
  [
    XInternAtom(display, "WM_PROTOCOLS", false),
    XInternAtom(display, "WM_DELETE_WINDOW", false),
    XInternAtom(display, "WM_STATE", false),
    XInternAtom(display, "WM_TAKE_FOCUS", false)
  ]

proc getNetAtoms*(display: PDisplay): array[ord(NetLast), TAtom] =
  [
    XInternAtom(display, "_NET_ACTIVE_WINDOW", false),
    XInternAtom(display, "_NET_SUPPORTED", false),
    XInternAtom(display, "_NET_SYSTEM_TRAY_S0", false),
    XInternAtom(display, "_NET_SYSTEM_TRAY_OPCODE", false),
    XInternAtom(display, "_NET_SYSTEM_TRAY_ORIENTATION", false),
    XInternAtom(display, "_NET_SYSTEM_TRAY_ORIENTATION_HORZ", false),
    XInternAtom(display, "_NET_WM_NAME", false),
    XInternAtom(display, "_NET_WM_STATE", false),
    XInternAtom(display, "_NET_SUPPORTING_WM_CHECK", false),
    XInternAtom(display, "_NET_WM_STATE_FULLSCREEN", false),
    XInternAtom(display, "_NET_CLIENT_LIST", false),
    XInternAtom(display, "_NET_WM_WINDOW_TYPE", false),
    XInternAtom(display, "_NET_WM_WINDOW_TYPE_NORMAL", false),
    XInternAtom(display, "_NET_WM_WINDOW_TYPE_DIALOG", false),
    XInternAtom(display, "_NET_WM_WINDOW_TYPE_UTILITY", false),
    XInternAtom(display, "_NET_WM_WINDOW_TYPE_TOOLBAR", false),
    XInternAtom(display, "_NET_WM_WINDOW_TYPE_SPLASH", false),
    XInternAtom(display, "_NET_WM_WINDOW_TYPE_MENU", false),
    XInternAtom(display, "_NET_WM_WINDOW_TYPE_DROPDOWN_MENU", false),
    XInternAtom(display, "_NET_WM_WINDOW_TYPE_POPUP_MENU", false),
    XInternAtom(display, "_NET_WM_WINDOW_TYPE_TOOLTIP", false),
    XInternAtom(display, "_NET_WM_WINDOW_TYPE_NOTIFICATION", false),
    XInternAtom(display, "_NET_WM_WINDOW_TYPE_DOCK", false)
  ]

proc getXAtoms*(display: PDisplay): array[ord(XLast), TAtom] =
  [
    XInternAtom(display, "MANAGER", false),
    XInternAtom(display, "_XEMBED", false),
    XInternAtom(display, "_XEMBED_INFO", false)
  ]

