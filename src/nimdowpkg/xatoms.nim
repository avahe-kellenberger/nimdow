import
  x11 / [x, xlib],
  options

export options

converter boolToXBool(x: bool): XBool = XBool(x)

type
  WMAtom* = enum
    WMName, WMProtocols, WMDelete, WMState, WMTakeFocus, WMLast
  NetAtom* = enum
    NetActiveWindow, NetSupported,
    NetSystemTray, NetSystemTrayOP, NetSystemTrayOrientation, NetSystemTrayOrientationHorz,
    NetWMName, NetWMState, NetWMStateAbove, NetWMStateSticky,
    NetSupportingWMCheck, NetWMStateFullScreen, NetClientList, NetWMStrutPartial,
    NetWMWindowType, NetWMWindowTypeNormal, NetWMWindowTypeDialog, NetWMWindowTypeUtility,
    NetWMWindowTypeToolbar, NetWMWindowTypeSplash, NetWMWindowTypeMenu,
    NetWMWindowTypeDropdownMenu, NetWMWindowTypePopupMenu, NetWMWindowTypeTooltip,
    NetWMWindowTypeNotification, NetWMWindowTypeDock,
    NetWMDesktop, NetDesktopViewport, NetNumberOfDesktops, NetCurrentDesktop, NetDesktopNames,
    NetLast
  XAtom* = enum
    Manager, Xembed, XembedInfo, XLast

var WMAtoms*: array[ord(WMLast), Atom]
var NetAtoms*: array[ord(NetLast), Atom]
var XAtoms*: array[ord(XLast), Atom]

template `$`*(atom: WMAtom): untyped =
  xatoms.WMAtoms[ord(atom)]

template `$`*(atom: NetAtom): untyped =
  xatoms.NetAtoms[ord(atom)]

template `$`*(atom: XAtom): untyped =
  xatoms.XAtoms[ord(atom)]


proc getWMAtoms*(display: PDisplay): array[ord(WMLast), Atom] =
  [
    XInternAtom(display, "WM_NAME", false),
    XInternAtom(display, "WM_PROTOCOLS", false),
    XInternAtom(display, "WM_DELETE_WINDOW", false),
    XInternAtom(display, "WM_STATE", false),
    XInternAtom(display, "WM_TAKE_FOCUS", false)
  ]

proc getNetAtoms*(display: PDisplay): array[ord(NetLast), Atom] =
  [
    XInternAtom(display, "_NET_ACTIVE_WINDOW", false),
    XInternAtom(display, "_NET_SUPPORTED", false),
    XInternAtom(display, "_NET_SYSTEM_TRAY_S0", false),
    XInternAtom(display, "_NET_SYSTEM_TRAY_OPCODE", false),
    XInternAtom(display, "_NET_SYSTEM_TRAY_ORIENTATION", false),
    XInternAtom(display, "_NET_SYSTEM_TRAY_ORIENTATION_HORZ", false),
    XInternAtom(display, "_NET_WM_NAME", false),
    XInternAtom(display, "_NET_WM_STATE", false),
    XInternAtom(display, "_NET_WM_STATE_ABOVE", false),
    XInternAtom(display, "_NET_WM_STATE_STICKY", false),
    XInternAtom(display, "_NET_SUPPORTING_WM_CHECK", false),
    XInternAtom(display, "_NET_WM_STATE_FULLSCREEN", false),
    XInternAtom(display, "_NET_CLIENT_LIST", false),
    XInternAtom(display, "_NET_WM_STRUT_PARTIAL", false),
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
    XInternAtom(display, "_NET_WM_WINDOW_TYPE_DOCK", false),
    XInternAtom(display, "_NET_WM_DESKTOP", false),
    XInternAtom(display, "_NET_DESKTOP_VIEWPORT", false),
    XInternAtom(display, "_NET_NUMBER_OF_DESKTOPS", false),
    XInternAtom(display, "_NET_CURRENT_DESKTOP", false),
    XInternAtom(display, "_NET_DESKTOP_NAMES", false)
  ]

proc getXAtoms*(display: PDisplay): array[ord(XLast), Atom] =
  [
    XInternAtom(display, "MANAGER", false),
    XInternAtom(display, "_XEMBED", false),
    XInternAtom(display, "_XEMBED_INFO", false)
  ]

proc getProperty*[T](
  display: PDisplay,
  window: Window,
  property: Atom,
): Option[T] =
  var
    actualTypeReturn: Atom
    actualFormatReturn: cint
    numItemsReturn: culong
    bytesAfterReturn: culong
    propReturn: ptr T

  discard XGetWindowProperty(
    display,
    window,
    property,
    0,
    0.clong.high,
    false,
    AnyPropertyType,
    actualTypeReturn.addr,
    actualFormatReturn.addr,
    numItemsReturn.addr,
    bytesAfterReturn.addr,
    cast[PPcuchar](propReturn.addr)
  )
  if numItemsReturn > 0.culong:
    return propReturn[].option
  else:
    return none(T)

proc getStringProperty*(
  display: PDisplay,
  window: Window,
  property: Atom,
): string =
  var
    actualTypeReturn: Atom
    actualFormatReturn: cint
    numItemsReturn: culong
    bytesAfterReturn: culong
    str: string = newString(300)
    propReturn = cast[ptr cstring](addr str)

  discard XGetWindowProperty(
    display,
    window,
    property,
    0,
    0.clong.high,
    false,
    AnyPropertyType,
    actualTypeReturn.addr,
    actualFormatReturn.addr,
    numItemsReturn.addr,
    bytesAfterReturn.addr,
    cast[PPcuchar](propReturn)
  )

  if numItemsReturn > 0.culong:
    let val = $propReturn[]
    return val
  else:
    return ""

proc getWindowName*(display: PDisplay, window: Window): string =
  ## Gets the name of the window by querying for NetWMName and WMName.
  var title = display.getStringProperty(window, $NetWMName)
  if title.len == 0:
    title = display.getStringProperty(window, $WMName)
  return title

proc sendEvent*(
  display: PDisplay,
  window: Window,
  protocol: Atom,
  mask: int,
  d0, d1, d2, d3, d4: clong
): bool =
  var
    event = XEvent()
    numProtocols: int
    exists: bool
    protocols: PAtom
    mt: Atom

  if protocol == $WMTakeFocus or protocol == $WMDelete:
    mt = $WMProtocols
    if XGetWMProtocols(
      display,
      window,
      protocols.addr,
      cast[Pcint](numProtocols.addr)
    ) != 0:
      let protocolsArr = cast[ptr UncheckedArray[Atom]](protocols)
      while not exists and numProtocols > 0:
        numProtocols.dec
        exists = protocolsArr[numProtocols] == protocol
      discard XFree(protocols)
  else:
    exists = true
    mt = protocol

  if exists:
    event.xclient.theType = ClientMessage
    event.xclient.window = window
    event.xclient.message_type = mt
    event.xclient.format = 32
    event.xclient.data.l[0] = d0
    event.xclient.data.l[1] = d1
    event.xclient.data.l[2] = d2
    event.xclient.data.l[3] = d3
    event.xclient.data.l[4] = d4
    discard XSendEvent(display, window, false, mask, addr(event))

  return exists

