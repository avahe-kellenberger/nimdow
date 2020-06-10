import
  x11 / [x, xlib, xutil, xatom, xft, xrender],
  xatoms,
  area

converter boolToXBool(x: bool): XBool = XBool(x)
converter intToCint(x: int): cint = x.cint
converter intToCuint(x: int): cuint = x.cuint
converter uintToCuint(x: uint): cuint = x.cuint

const
  barName = "nimbar"
  fontString = "monospace:size=8"
  cellWidth = 21

type
  StatusBar* = object
    display: PDisplay
    screen: cint
    barWindow*: Window
    rootWindow: Window
    font: PXftFont
    draw: PXftDraw
    visual: PVisual
    colormap: Colormap
    fgColor, bgColor, selectedFgColor: XftColor
    area: Area

proc createBar(this: StatusBar): Window
proc configureBar(this: StatusBar)
proc configureColors(this: StatusBar)
proc configureFont(this: StatusBar): PXftFont
proc renderTags(this: StatusBar, selectedTag: int)

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
  result.font = result.configureFont()

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

proc configureFont(this: StatusBar): PXftFont =
  result = XftFontOpenXlfd(this.display, this.screen, fontString)
  if result == nil:
    result = XftFontOpenName(this.display, this.screen, fontString)
  if result == nil:
    quit "Failed to load font"

######################
### Rendering procs ##
######################

#proc renderString*(str: var string, x: int, alignRight: bool): int16 =
#  ## Renders a string at position x.
#  ## If alignRight is true,
#  ## the string will be rendered from the right side of the bar (barWidth - x).
#  ## Returns the x offset
#  var extents: XGlyphInfo
#  var strAddr = cast[PFcChar8](str[0].addr)
#  XftTextExtentsUtf8(display, font, strAddr, str.len, extents.addr)

#  if alignRight:
#    XftDrawRect(draw, bgColor.addr, (x - extents.xOff), 0, extents.xOff.cuint, barHeight)
#    XftDrawStringUtf8(
#      draw,
#      fgColor.addr,
#      font,
#      x - extents.xOff,
#      1 + font.ascent,
#      strAddr,
#      str.len
#    )
#  else:
#    XftDrawRect(draw, bgColor.addr, x, 0, extents.xOff.cuint, barHeight)
#    XftDrawStringUtf8(
#      draw, fgColor.addr, font,
#      x,
#      (1 + font.ascent),
#      strAddr,
#      str.len
#    )
#  return extents.xOff

proc renderTags(this: StatusBar, selectedTag: int) =
  var
    extents: XGlyphInfo
    tagStr: string
    textXPos: int

  # TODO:
  let numTags = 9

  for i in countup(0, numTags - 1):
    # Text x position
    textXPos = cellWidth * i

    tagStr = $(i + 1)
    let tagStrAddr = cast[PFcChar8](tagStr[0].addr)
    XftTextExtentsUtf8(this.display, this.font, tagStrAddr, tagStr.len, extents.addr)

    var currentFgColor: XftColor

    # Tag is selected
    if i == selectedTag:
      currentFgColor = this.selectedFgColor
    else:
      currentFgColor = this.fgColor

    XftDrawRect(this.draw, this.bgColor.unsafeAddr, textXPos, 0, cellWidth, this.area.height)

    XftDrawStringUtf8(
      this.draw,
      currentFgColor.addr,
      this.font,
      textXPos + ((cellWidth - extents.xOff) / 2).int,
      this.font.ascent + (this.area.height.int - this.font.height) div 2,
      tagStrAddr,
      tagStr.len
    )

proc redraw*(this: StatusBar, selectedTag: int) =
  # Will add calls to other functions which will render more info
  XftDrawRect(this.draw, this.bgColor.unsafeAddr, 0, 0, this.area.width, this.area.height)
  this.renderTags(selectedTag)

proc closeBar*(this: StatusBar) =
  this.freeColor(this.fgColor.unsafeAddr)
  this.freeColor(this.selectedFgColor.unsafeAddr)
  this.freeColor(this.bgColor.unsafeAddr)

  XftFontClose(this.display, this.font)
  XftDrawDestroy(this.draw)
  discard XDestroyWindow(this.display, this.barWindow)
  discard XCloseDisplay(this.display)

