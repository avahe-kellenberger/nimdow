import
  x11 / [x, xlib, xutil, xatom, xft, xrender],
  xatoms,
  area

converter boolToXBool(x: bool): XBool = XBool(x)
converter XBoolToBool(x: XBool): bool = bool(x)
converter intToCint(x: int): cint = x.cint
converter intToCuint(x: int): cuint = x.cuint
converter uintToCuint(x: uint): cuint = x.cuint

const
  barName = "nimbar"
  numTags = 9
  # TODO: These should all be loaded from the settings or passed in as params
  fontStrings = ["monospace:size=8", "JoyPixels:pixelsize=10:antialias=true:autohint=true"]
  cellWidth = 21
  rightPadding = 4

type
  StatusBar* = object
    status*: string
    display: PDisplay
    screen: cint
    barWindow*: Window
    rootWindow: Window
    fonts: seq[PXftFont]
    draw: PXftDraw
    visual: PVisual
    colormap: Colormap
    fgColor*, bgColor*, selectedFgColor*: XftColor
    area*: Area

proc createBar(this: StatusBar): Window
proc configureBar(this: StatusBar)
proc configureColors(this: StatusBar)
proc configureFont(this: StatusBar, fontString: string): PXftFont

proc newStatusBar*(display: PDisplay, rootWindow: Window, area: Area): StatusBar =
  result = StatusBar(display: display, rootWindow: rootWindow)
  result.screen = DefaultScreen(display)
  result.visual = DefaultVisual(display, result.screen)
  result.colormap = DefaultColormap(display, result.screen)
  result.area = area
  result.barWindow = result.createBar()
  result.draw = XftDrawCreate(display, result.barWindow, result.visual, result.colormap)

  result.configureBar()
  result.configureColors()
  result.fonts = @[]
  for fontString in fontStrings:
    result.fonts.add(result.configureFont(fontString))

  discard XSelectInput(
    display,
    result.barWindow,
    ExposureMask
  )
  discard XMapWindow(display, result.barWindow)
  discard XFlush(display)

proc createBar(this: StatusBar): Window =
  var windowAttr: XSetWindowAttributes
  # windowAttr.override_redirect = true
  windowAttr.background_pixmap = ParentRelative
  windowAttr.event_mask = ExposureMask

  return XCreateWindow(
    this.display,
    this.rootWindow,
    this.area.x,
    this.area.y,
    this.area.width,
    this.area.height,
    0,
    DefaultDepth(this.display, this.screen),
    CopyFromParent,
    this.visual,
    CWOverrideRedirect or CWBackPixmap or CWEventMask,
    windowAttr.addr
  )

proc configureBar(this: StatusBar) =
  var classHint: PXClassHint = XAllocClassHint()
  classHint.res_name = barName
  classHint.res_class = barName
  discard XSetClassHint(this.display, this.barWindow, classHint)
  discard XFree(classHint)
  discard XStoreName(this.display, this.barWindow, barName)

  var data: Atom = $NetWMWindowTypeDock
  discard XChangeProperty(
    this.display,
    this.barWindow,
    $NetWMWindowType,
    XA_ATOM,
    32,
    PropModeReplace,
    cast[Pcuchar](data.addr),
    1
  )

  data = $NetWMStateAbove
  discard XChangeProperty(
    this.display,
    this.barWindow,
    $NetWMState,
    XA_ATOM,
    32,
    PropModeReplace,
    cast[Pcuchar](data.addr),
    1
  )

  data = $NetWMStateSticky
  discard XChangeProperty(
    this.display,
    this.barWindow,
    $NetWMState,
    XA_ATOM,
    32,
    PropModeAppend,
    cast[Pcuchar](data.addr),
    1
  )

  # TODO: Strut properties should be passed in as params.
  var strut: Strut
  strut.top = this.area.height
  strut.topStartX = this.area.x.culong
  strut.topEndX = strut.topStartX + this.area.width - 1

  discard XChangeProperty(
    this.display,
    this.barWindow,
    $NetWMStrutPartial,
    XA_CARDINAL,
    32,
    PropModeReplace,
    cast[Pcuchar](strut.addr),
    12
  )  

proc allocColor(this: StatusBar, color: PXRenderColor, colorPtr: PXftColor) =
  let result = XftColorAllocValue(
    this.display,
    this.visual,
    this.colormap,
    color,
    colorPtr
  )
  if result != 1:
    echo "Failed to alloc color!"

proc freeColor(this: StatusBar, color: PXftColor) =
  XftColorFree(this.display, this.visual, this.colormap, color)

proc configureColors(this: StatusBar) =
  # TODO: Load colors from a config file
  block foreground:
    var color: XRenderColor
    # #fce8c3
    color.red = 0xfc * 256
    color.green = 0xe8 * 256
    color.blue = 0xc3 * 256
    this.allocColor(color.addr, this.fgColor.unsafeAddr)

  block background:
    var color: XRenderColor
    # #1c1b19
    color.red = 0x1c * 256
    color.green = 0x1b * 256
    color.blue = 0x19 * 256
    this.allocColor(color.addr, this.bgColor.unsafeAddr)

  block selectedBackground:
    var color: XRenderColor
    # #519f50
    color.red = 0x51 * 256
    color.green = 0x9f * 256
    color.blue = 0x50 * 256
    this.allocColor(color.addr, this.selectedFgColor.unsafeAddr)

proc configureFont(this: StatusBar, fontString: string): PXftFont =
  result = XftFontOpenXlfd(this.display, this.screen, fontString)
  if result == nil:
    result = XftFontOpenName(this.display, this.screen, fontString)
  if result == nil:
    quit "Failed to load font"

######################
### Rendering procs ##
######################

proc renderString*(this: StatusBar, str: string, x: int, color: XftColor, alignRight: bool = false) =
  ## Renders a string at position x.
  ## If alignRight is true,
  ## the string will be rendered from the right side of the bar (barWidth - x).
  var
    extents: XGlyphInfo
    strAddr = cast[PFcChar8](str[0].unsafeAddr)
    xLoc = x

  let font = this.fonts[0]
  XftTextExtentsUtf8(this.display, font, strAddr, str.len, extents.addr)
  let centerY = font.ascent + (this.area.height.int - font.height) div 2

  if alignRight:
    xLoc -= extents.xOff

  XftDrawRect(
    this.draw,
    this.bgColor.unsafeAddr,
    xLoc,
    0,
    extents.xOff.cuint,
    this.area.height
   )
  XftDrawStringUtf8(
    this.draw,
    color.unsafeAddr,
    font,
    xLoc,
    centerY,
    strAddr,
    str.len
  )

proc renderTags*(this: StatusBar, selectedTag: int) =
  var
    tagStr: string
    textXPos: int

  for i in countup(0, numTags - 1):
    # Text x position
    textXPos = cellWidth div 2 + cellWidth * i
    tagStr = $(i + 1)
    if i == selectedTag:
      this.renderString(tagStr, textXPos, this.selectedFgColor)
    else:
      this.renderString(tagStr, textXPos, this.fgColor)

proc renderStatus(this: StatusBar) =
  if this.status.len > 0:
    this.renderString(this.status, this.area.width.int - rightPadding, this.fgColor, true)

proc setStatus*(this: var StatusBar, status: string) =
  this.status = status
  this.renderStatus()

proc redraw*(this: StatusBar, selectedTag: int) =
  # Will add calls to other functions which will render more info
  XftDrawRect(this.draw, this.bgColor.unsafeAddr, 0, 0, this.area.width, this.area.height)
  this.renderTags(selectedTag)
  this.renderStatus()

proc closeBar*(this: StatusBar) =
  this.freeColor(this.fgColor.unsafeAddr)
  this.freeColor(this.selectedFgColor.unsafeAddr)
  this.freeColor(this.bgColor.unsafeAddr)

  for font in this.fonts:
    XftFontClose(this.display, font)
  XftDrawDestroy(this.draw)
  discard XDestroyWindow(this.display, this.barWindow)
  discard XCloseDisplay(this.display)

