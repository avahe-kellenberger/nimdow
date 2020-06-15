import
  x11 / [x, xlib, xutil, xatom, xft, xrender],
  unicode,
  xatoms,
  area,
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

proc createBar(this: StatusBar): Window
proc configureBar(this: StatusBar)
proc configureColors(this: StatusBar)
proc configureFont(this: StatusBar, fontString: string): PXftFont

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
  result.fonts = @[]
  for fontString in settings.fonts:
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

proc toRGB(hex: int): tuple[r, g, b: int] =
  return (
    (hex shr 16) and 0xff,
    (hex shr 8) and 0xff,
    hex and 0xff
  )

proc configureColors(this: StatusBar) =
  block foreground:
    var
      color: XRenderColor
      rgb = toRGB(this.settings.fgColor)
    color.red = rgb.r.cushort * 256
    color.green = rgb.g.cushort * 256
    color.blue = rgb.b.cushort * 256
    this.allocColor(color.addr, this.fgColor.unsafeAddr)

  block background:
    var
      color: XRenderColor
      rgb = toRGB(this.settings.bgColor)
    color.red = rgb.r.cushort * 256
    color.green = rgb.g.cushort * 256
    color.blue = rgb.b.cushort * 256
    this.allocColor(color.addr, this.bgColor.unsafeAddr)

  block selectionColor:
    var
      color: XRenderColor
      rgb = toRGB(this.settings.selectionColor)
    color.red = rgb.r.cushort * 256
    color.green = rgb.g.cushort * 256
    color.blue = rgb.b.cushort * 256
    this.allocColor(color.addr, this.selectionColor.unsafeAddr)

proc configureFont(this: StatusBar, fontString: string): PXftFont =
  result = XftFontOpenXlfd(this.display, this.screen, fontString)
  if result == nil:
    result = XftFontOpenName(this.display, this.screen, fontString)
  if result == nil:
    quit "Failed to load font"

######################
### Rendering procs ##
######################

proc renderStringRightAligned(this: StatusBar, str: string, x: int, color: XftColor) =
  ## Renders a string at position x from the right side of the bar (barWidth - x).
  var
    extents: XGlyphInfo
    pos = str.len
    xLoc = x

  let runes = str.toRunes()
  for i in countdown(runes.high, runes.low):
    let rune = runes[i]
    pos -= rune.size
    let runeAddr = cast[PFcChar8](str[pos].unsafeAddr)
    for font in this.fonts:
      if XftCharExists(this.display, font, rune.FcChar32) == 1:
        XftTextExtentsUtf8(this.display, font, runeAddr, rune.size, extents.addr)
        let centerY = font.ascent + (this.area.height.int - font.height) div 2
        xLoc -= extents.xOff
        XftDrawStringUtf8(
          this.draw,
          color.unsafeAddr,
          font,
          xLoc,
          centerY,
          runeAddr,
          rune.size
        )
        break

proc renderStringCentered*(this: StatusBar, str: string, x: int, color: XftColor) =
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

  xLoc = x - (stringWidth div 2)
  pos = 0
  for (rune, font, glyph) in runeInfo:
    let runeAddr = cast[PFcChar8](str[pos].unsafeAddr)
    pos += rune.size
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

proc renderString*(this: StatusBar, str: string, x: int, color: XftColor) =
  ## Renders a string at position x.
  var
    extents: XGlyphInfo
    pos = 0
    xLoc = x

  for rune in str.runes:
    let runeAddr = cast[PFcChar8](str[pos].unsafeAddr)
    pos += rune.size
    for font in this.fonts:
      if XftCharExists(this.display, font, rune.FcChar32) == 1:
        XftTextExtentsUtf8(this.display, font, runeAddr, rune.size, extents.addr)
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
        xLoc += extents.xOff
        break

proc renderTags(this: StatusBar, selectedTag: int) =
  var textXPos: int

  for tag, clients in this.taggedClients:
    let i = tag.id
    textXPos = cellWidth div 2 + cellWidth * i
    var color = if i == selectedTag: this.selectionColor else: this.fgColor
    this.renderString($(i + 1), textXPos, color)
    if clients.len > 0:
      XftDrawRect(this.draw, color.addr, i * cellWidth, 0, 4, 4)
      if this.selectedClient == nil or clients.find(this.selectedClient) == -1:
        XftDrawRect(this.draw, this.bgColor.unsafeAddr, i * cellWidth + 1, 1, 2, 2)

proc renderStatus(this: StatusBar) =
  if this.status.len > 0:
    this.renderStringRightAligned(this.status, this.area.width.int - rightPadding, this.fgColor)

proc renderActiveWindowTitle(this: StatusBar) =
  if this.activeWindowTitle.len > 0:
    this.renderStringCentered(this.activeWindowTitle, this.area.width.int div 2, this.selectionColor)

proc redraw*(this: var StatusBar, selectedTag: int) =
  this.selectedTag = selectedTag
  XftDrawRect(this.draw, this.bgColor.unsafeAddr, 0, 0, this.area.width, this.area.height)
  this.renderTags(selectedTag)
  this.renderStatus()
  this.renderActiveWindowTitle()

proc setSelectedClient*(this: var StatusBar, client: Client, redraw: bool = true) =
  this.selectedClient = client
  if redraw:
    this.redraw(this.selectedTag)

proc setStatus*(this: var StatusBar, status: string, redraw: bool = true) =
  this.status = status
  if redraw:
    this.redraw(this.selectedTag)

proc setActiveWindowTitle*(this: var StatusBar, title: string, redraw: bool = true) =
  this.activeWindowTitle = title
  if redraw:
    this.redraw(this.selectedTag)

proc closeBar*(this: StatusBar) =
  this.freeColor(this.fgColor.unsafeAddr)
  this.freeColor(this.selectionColor.unsafeAddr)
  this.freeColor(this.bgColor.unsafeAddr)

  for font in this.fonts:
    XftFontClose(this.display, font)
  XftDrawDestroy(this.draw)
  discard XDestroyWindow(this.display, this.barWindow)
  discard XCloseDisplay(this.display)

