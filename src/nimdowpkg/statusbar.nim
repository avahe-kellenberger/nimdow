import
  x11 / [x, xlib, xutil, xatom, xft, xrender],
  unicode,
  xatoms,
  area,
  strut,
  tables,
  tag,
  client,
  config/configloader

converter boolToXBool(x: bool): XBool = XBool(x)
converter XBoolToBool(x: XBool): bool = bool(x)
converter intToCint(x: int): cint = x.cint
converter intToCuint(x: int): cuint = x.cuint
converter uintToCuint(x: uint): cuint = x.cuint

const
  barName = "nimbar"
  cellWidth = 21
  rightPadding = 4

type
  StatusBar* = object
    settings: BarSettings
    isMonitorSelected: bool
    status: string
    taggedClients: OrderedTableRef[Tag, seq[Client]]
    selectedClient: Client
    selectedTag: int
    activeWindowTitle: string
    display: PDisplay
    screen: cint
    barWindow*: Window
    rootWindow: Window
    fonts: seq[PXftFont]
    draw: PXftDraw
    visual: PVisual
    colormap: Colormap
    fgColor*, bgColor*, selectionColor*: XftColor
    area*: Area
    systrayWidth: int

proc createBar(this: StatusBar): Window
proc configureBar(this: StatusBar)
proc configureColors(this: StatusBar)
proc configureFonts(this: var StatusBar)
proc freeAllColors(this: StatusBar)
proc redraw*(this: StatusBar)

proc newStatusBar*(
    display: PDisplay,
    rootWindow: Window,
    area: Area,
    taggedClients: OrderedTableRef[Tag, seq[Client]],
    settings: BarSettings
): StatusBar =
  result = StatusBar(display: display, rootWindow: rootWindow)
  result.settings = settings
  result.taggedClients = taggedClients
  result.screen = DefaultScreen(display)
  result.visual = DefaultVisual(display, result.screen)
  result.colormap = DefaultColormap(display, result.screen)
  result.area = area
  result.barWindow = result.createBar()
  result.draw = XftDrawCreate(display, result.barWindow, result.visual, result.colormap)

  result.configureBar()
  result.configureColors()
  result.configureFonts()

  discard XSelectInput(
    display,
    result.barWindow,
    ExposureMask
  )
  discard XMapWindow(display, result.barWindow)
  discard XFlush(display)

template currentWidth(this: StatusBar): int =
  this.area.width.int - this.systrayWidth

proc createBar(this: StatusBar): Window =
  var windowAttr: XSetWindowAttributes
  windowAttr.background_pixmap = ParentRelative
  windowAttr.event_mask = ExposureMask

  return XCreateWindow(
    this.display,
    this.rootWindow,
    this.area.x,
    this.area.y,
    this.currentWidth,
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

  var strut: Strut
  strut.top = this.area.height
  strut.topStartX = this.area.x.culong
  strut.topEndX = strut.topStartX + this.currentWidth - 1

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

proc resizeForSystray*(this: var StatusBar, systrayWidth: int, redraw: bool = true) =
  this.systrayWidth = systrayWidth
  discard XMoveResizeWindow(
    this.display,
    this.barWindow,
    this.area.x,
    this.area.y,
    this.currentWidth,
    this.area.height
  )
  this.redraw()

proc allocColor(this: StatusBar, color: PXRenderColor, colorPtr: PXftColor) =
  let result = XftColorAllocValue(
    this.display,
    this.visual,
    this.colormap,
    color,
    colorPtr
  )
  if result == 0:
    echo "Failed to alloc color!"

proc freeColor(this: StatusBar, color: PXftColor) =
  XftColorFree(this.display, this.visual, this.colormap, color)

proc freeAllColors(this: StatusBar) =
  this.freeColor(this.fgColor.unsafeAddr)
  this.freeColor(this.selectionColor.unsafeAddr)
  this.freeColor(this.bgColor.unsafeAddr)

proc toRGB(hex: int): tuple[r, g, b: int] =
  return (
    (hex shr 16) and 0xff,
    (hex shr 8) and 0xff,
    hex and 0xff
  )

template configureColor(this: StatusBar, hexColor: int, xftColor: XftColor) =
  var
    color: XRenderColor
    rgb = toRGB(hexColor)
  color.red = rgb.r.cushort * 256
  color.green = rgb.g.cushort * 256
  color.blue = rgb.b.cushort * 256
  this.allocColor(color.addr, xftColor.unsafeAddr)

proc configureColors(this: StatusBar) =
  this.configureColor(this.settings.fgColor, this.fgColor)
  this.configureColor(this.settings.bgColor, this.bgColor)
  this.configureColor(this.settings.selectionColor, this.selectionColor)

proc configureFont(this: StatusBar, fontString: string): PXftFont =
  result = XftFontOpenXlfd(this.display, this.screen, fontString)
  if result == nil:
    result = XftFontOpenName(this.display, this.screen, fontString)
  if result == nil:
    quit "Failed to load font"

proc configureFonts(this: var StatusBar) =
  this.fonts = @[]
  for fontString in this.settings.fonts:
    this.fonts.add(this.configureFont(fontString))

proc setConfig*(this: var StatusBar, config: BarSettings, redraw: bool = true) =
  this.freeAllColors()
  for font in this.fonts:
    XftFontClose(this.display, font)

  this.settings = config
  this.area.height = config.height
  this.configureColors()
  this.configureFonts()

  # Tell bar to resize and redraw
  this.resizeForSystray(this.systrayWidth, redraw)

######################
### Rendering procs ##
######################

proc renderStringRightAligned(this: StatusBar, str: string, x: int, color: XftColor): int =
  ## Renders a string at position x from the right side of the bar (barWidth - x).
  ## Returns the length of the rendered string in pixels.
  var
    glyph: XGlyphInfo
    pos = str.len
    xLoc = x
    stringWidth: int

  let runes = str.toRunes()
  for i in countdown(runes.high, runes.low):
    let rune = runes[i]
    pos -= rune.size
    let runeAddr = cast[PFcChar8](str[pos].unsafeAddr)
    for font in this.fonts:
      if XftCharExists(this.display, font, rune.FcChar32) == 1:
        XftTextExtentsUtf8(this.display, font, runeAddr, rune.size, glyph.addr)
        let centerY = font.ascent + (this.area.height.int - font.height) div 2
        xLoc -= glyph.xOff
        XftDrawStringUtf8(
          this.draw,
          color.unsafeAddr,
          font,
          xLoc,
          centerY,
          runeAddr,
          rune.size
        )
        stringWidth.inc glyph.xOff
        break

  return stringWidth

proc renderStringCentered*(
  this: StatusBar,
  str: string,
  x: int,
  color: XftColor,
  minRenderX: int = 0,
  maxRenderX: int = 0
) =
  ## Renders a string centered at position x.

  # TODO:
  # 1. There may be a more efficient way to do this.
  # 2. We need to make sure the text doesn't bleed into the status or tags.
  # Maybe we should store the entire width of those strings and their locations.
  var
    runeInfo: seq[(Rune, PXftFont, XGlyphInfo)]
    stringWidth, xLoc, pos: int

  for rune in str.runes:
    let runeAddr = cast[PFcChar8](str[pos].unsafeAddr)
    pos += rune.size
    for font in this.fonts:
      if XftCharExists(this.display, font, rune.FcChar32) == 1:
        var glyph: XGlyphInfo
        XftTextExtentsUtf8(this.display, font, runeAddr, rune.size, glyph.addr)
        runeInfo.add((rune, font, glyph))
        stringWidth += glyph.xOff
        break

  xLoc = max(minRenderX, x - (stringWidth div 2))
  pos = 0
  for (rune, font, glyph) in runeInfo:
    let runeAddr = cast[PFcChar8](str[pos].unsafeAddr)
    pos += rune.size
    if xLoc >= maxRenderX:
      break
    let centerY = font.ascent + (this.area.height.int - font.height) div 2
    XftDrawStringUtf8(
      this.draw,
      color.unsafeAddr,
      font,
      xLoc,
      centerY,
      runeAddr,
      rune.size
    )
    xLoc += glyph.xOff

proc renderString*(this: StatusBar, str: string, x: int, color: XftColor): int =
  ## Renders a string at position x.
  ## Returns the length of the rendered string in pixels.
  var
    glyph: XGlyphInfo
    pos = 0
    xLoc = x
    stringWidth: int

  for rune in str.runes:
    let runeAddr = cast[PFcChar8](str[pos].unsafeAddr)
    pos += rune.size
    for font in this.fonts:
      if XftCharExists(this.display, font, rune.FcChar32) == 1:
        XftTextExtentsUtf8(this.display, font, runeAddr, rune.size, glyph.addr)
        let centerY = font.ascent + (this.area.height.int - font.height) div 2
        XftDrawStringUtf8(
          this.draw,
          color.unsafeAddr,
          font,
          xLoc,
          centerY,
          runeAddr,
          rune.size
        )
        xLoc += glyph.xOff
        stringWidth += glyph.xOff
        break

  return stringWidth

proc renderTags(this: StatusBar, selectedTag: int): int =
  var
    textXPos: int

  for tag, clients in this.taggedClients:
    let i = tag.id
    textXPos = cellWidth div 2 + cellWidth * i
    var color = if i == selectedTag: this.selectionColor else: this.fgColor
    discard this.renderString($(i + 1), textXPos, color)
    if clients.len > 0:
      XftDrawRect(this.draw, color.addr, i * cellWidth, 0, 4, 4)
      if this.selectedClient == nil or clients.find(this.selectedClient) == -1:
        XftDrawRect(this.draw, this.bgColor.unsafeAddr, i * cellWidth + 1, 1, 2, 2)

  return textXPos + cellWidth

proc renderStatus(this: StatusBar): int =
  if this.status.len > 0:
    result = this.renderStringRightAligned(
      this.status,
      this.currentWidth - rightPadding,
      this.fgColor
    )

proc renderActiveWindowTitle(this: StatusBar, minRenderX, maxRenderX: int) =
  if this.activeWindowTitle.len > 0:
    let textColor =
      if this.isMonitorSelected:
        this.selectionColor
      else:
        this.fgColor
    this.renderStringCentered(
      this.activeWindowTitle,
      this.area.width.int div 2,
      textColor,
      minRenderX,
      maxRenderX
    )

proc clearBar(this: StatusBar) =
  XftDrawRect(this.draw, this.bgColor.unsafeAddr, 0, 0, this.currentWidth, this.area.height)

proc redraw*(this: StatusBar) =
  this.clearBar()
  let
    tagLengthPixels = this.renderTags(this.selectedTag)
    maxRenderX = this.currentWidth - this.renderStatus() - cellWidth
  this.renderActiveWindowTitle(tagLengthPixels, maxRenderX)

proc setIsMonitorSelected*(this: var StatusBar, isMonitorSelected: bool, redraw: bool = true) =
  this.isMonitorSelected = isMonitorSelected
  if redraw:
    this.redraw

proc setSelectedTag*(this: var StatusBar, selectedTag: int, redraw: bool = true) =
  this.selectedTag = selectedTag
  if redraw:
    this.redraw()

proc setSelectedClient*(this: var StatusBar, client: Client, redraw: bool = true) =
  if this.selectedClient == client:
    return
  this.selectedClient = client
  if redraw:
    this.redraw()

proc setStatus*(this: var StatusBar, status: string, redraw: bool = true) =
  if this.status == status:
    return
  this.status = status
  if redraw:
    this.redraw()

proc setActiveWindowTitle*(this: var StatusBar, title: string, redraw: bool = true) =
  if this.activeWindowTitle == title:
    return
  this.activeWindowTitle = title
  if redraw:
    this.redraw()

proc closeBar*(this: StatusBar) =
  this.freeAllColors()
  for font in this.fonts:
    XftFontClose(this.display, font)
  XftDrawDestroy(this.draw)
  discard XDestroyWindow(this.display, this.barWindow)

