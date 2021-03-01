import
  x11 / [x, xlib, xutil, xatom, xft, xrender],
  lists,
  tables,
  sets,
  unicode,
  strutils

import
  taggedclients,
  xatoms,
  area,
  strut,
  logger,
  windowtitleposition,
  config/configloader,
  config/tagsettings

converter XBoolToBool(x: XBool): bool = bool(x)
converter boolToXBool(x: bool): XBool = x.XBool
converter intToCint(x: int): cint = x.cint
converter intToCuint(x: int): cuint = x.cuint
converter uintToCuint(x: uint): cuint = x.cuint

const
  barName = "nimbar"
  boxWidth = 4
  rightPadding = 4

type
  StatusBar* = object
    settings: BarSettings
    tagSettings*: OrderedTable[TagID, TagSetting]
    isMonitorSelected: bool
    status: string
    activeWindowTitle: string
    windowTitlePosition: WindowTitlePosition
    display: PDisplay
    screen: cint
    barWindow*: Window
    rootWindow: Window
    fonts: seq[PXftFont]
    draw: PXftDraw
    visual: PVisual
    colormap: Colormap
    fgColor*, bgColor*, selectionColor*, urgentColor*: XftColor
    area*: Area
    systrayWidth: int

    # Client and tag info.
    taggedClients: TaggedClients

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
    settings: BarSettings,
    taggedClients: TaggedClients,
    tagSettings: OrderedTable[TagID, TagSetting]
): StatusBar =
  result = StatusBar(display: display, rootWindow: rootWindow)
  result.settings = settings
  result.windowTitlePosition = settings.windowTitlePosition
  result.tagSettings = tagSettings
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

template tags*(this: StatusBar): seq[Tag] =
  this.taggedClients.tags

template selectedTags*(this: StatusBar): OrderedSet[TagID] =
  this.taggedClients.selectedTags

template clients*(this: StatusBar): DoublyLinkedList[Client] =
  this.taggedClients.clients

template clientSelection*(this: StatusBar): DoublyLinkedList[Client] =
  this.taggedClients.clientSelection

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
  strut.topEndX = strut.topStartX + this.currentWidth.culong - 1

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
    log "Failed to alloc color!", lvlError

proc freeColor(this: StatusBar, color: PXftColor) =
  XftColorFree(this.display, this.visual, this.colormap, color)

proc freeAllColors(this: StatusBar) =
  this.freeColor(this.fgColor.unsafeAddr)
  this.freeColor(this.bgColor.unsafeAddr)
  this.freeColor(this.selectionColor.unsafeAddr)
  this.freeColor(this.urgentColor.unsafeAddr)

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
  color.red = rgb.r.cushort shl 8
  color.green = rgb.g.cushort shl 8
  color.blue = rgb.b.cushort shl 8
  color.alpha = 255 shl 8
  this.allocColor(color.addr, xftColor.unsafeAddr)

proc configureColors(this: StatusBar) =
  this.configureColor(this.settings.fgColor, this.fgColor)
  this.configureColor(this.settings.bgColor, this.bgColor)
  this.configureColor(this.settings.selectionColor, this.selectionColor)
  this.configureColor(this.settings.urgentColor, this.urgentColor)

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

proc setConfig*(this: var StatusBar, config: BarSettings, tagSettings: TagSettings, redraw: bool = true) =
  this.freeAllColors()
  for font in this.fonts:
    XftFontClose(this.display, font)

  this.settings = config
  this.windowTitlePosition = this.settings.windowTitlePosition
  this.tagSettings = tagSettings
  this.area.height = config.height
  this.configureColors()
  this.configureFonts()

  # Tell bar to resize and redraw
  this.resizeForSystray(this.systrayWidth, redraw)

######################
### Rendering procs ##
######################

# Colors for ANSI CSI SGR coloration
const
  basicColors = [0x000000, 0xcd0000, 0x00cd00, 0xcdcd00,
                 0x0000ee, 0xcd00cd, 0x00cdcd, 0xe5e5e5]
  brightColors = [0x7f7f7f, 0xff0000, 0x00ff00, 0xffff00,
                  0x5c5cff, 0xff00ff, 0x00ffff, 0xffffff]
  extraColors = [0x000000, 0x800000, 0x008000, 0x808000,
                 0x000080, 0x800080, 0x008080, 0xc0c0c0,
                 0x808080, 0xff0000, 0x00ff00, 0xffff00,
                 0x0000ff, 0xff00ff, 0x00ffff, 0xffffff,
                 0x000000, 0x00005f, 0x000087, 0x0000af,
                 0x0000d7, 0x0000ff, 0x005f00, 0x005f5f,
                 0x005f87, 0x005faf, 0x005fd7, 0x005fff,
                 0x008700, 0x00875f, 0x008787, 0x0087af,
                 0x0087d7, 0x0087ff, 0x00af00, 0x00af5f,
                 0x00af87, 0x00afaf, 0x00afd7, 0x00afff,
                 0x00d700, 0x00d75f, 0x00d787, 0x00d7af,
                 0x00d7d7, 0x00d7ff, 0x00ff00, 0x00ff5f,
                 0x00ff87, 0x00ffaf, 0x00ffd7, 0x00ffff,
                 0x5f0000, 0x5f005f, 0x5f0087, 0x5f00af,
                 0x5f00d7, 0x5f00ff, 0x5f5f00, 0x5f5f5f,
                 0x5f5f87, 0x5f5faf, 0x5f5fd7, 0x5f5fff,
                 0x5f8700, 0x5f875f, 0x5f8787, 0x5f87af,
                 0x5f87d7, 0x5f87ff, 0x5faf00, 0x5faf5f,
                 0x5faf87, 0x5fafaf, 0x5fafd7, 0x5fafff,
                 0x5fd700, 0x5fd75f, 0x5fd787, 0x5fd7af,
                 0x5fd7d7, 0x5fd7ff, 0x5fff00, 0x5fff5f,
                 0x5fff87, 0x5fffaf, 0x5fffd7, 0x5fffff,
                 0x870000, 0x87005f, 0x870087, 0x8700af,
                 0x8700d7, 0x8700ff, 0x875f00, 0x875f5f,
                 0x875f87, 0x875faf, 0x875fd7, 0x875fff,
                 0x878700, 0x87875f, 0x878787, 0x8787af,
                 0x8787d7, 0x8787ff, 0x87af00, 0x87af5f,
                 0x87af87, 0x87afaf, 0x87afd7, 0x87afff,
                 0x87d700, 0x87d75f, 0x87d787, 0x87d7af,
                 0x87d7d7, 0x87d7ff, 0x87ff00, 0x87ff5f,
                 0x87ff87, 0x87ffaf, 0x87ffd7, 0x87ffff,
                 0xaf0000, 0xaf005f, 0xaf0087, 0xaf00af,
                 0xaf00d7, 0xaf00ff, 0xaf5f00, 0xaf5f5f,
                 0xaf5f87, 0xaf5faf, 0xaf5fd7, 0xaf5fff,
                 0xaf8700, 0xaf875f, 0xaf8787, 0xaf87af,
                 0xaf87d7, 0xaf87ff, 0xafaf00, 0xafaf5f,
                 0xafaf87, 0xafafaf, 0xafafd7, 0xafafff,
                 0xafd700, 0xafd75f, 0xafd787, 0xafd7af,
                 0xafd7d7, 0xafd7ff, 0xafff00, 0xafff5f,
                 0xafff87, 0xafffaf, 0xafffd7, 0xafffff,
                 0xd70000, 0xd7005f, 0xd70087, 0xd700af,
                 0xd700d7, 0xd700ff, 0xd75f00, 0xd75f5f,
                 0xd75f87, 0xd75faf, 0xd75fd7, 0xd75fff,
                 0xd78700, 0xd7875f, 0xd78787, 0xd787af,
                 0xd787d7, 0xd787ff, 0xd7af00, 0xd7af5f,
                 0xd7af87, 0xd7afaf, 0xd7afd7, 0xd7afff,
                 0xd7d700, 0xd7d75f, 0xd7d787, 0xd7d7af,
                 0xd7d7d7, 0xd7d7ff, 0xd7ff00, 0xd7ff5f,
                 0xd7ff87, 0xd7ffaf, 0xd7ffd7, 0xd7ffff,
                 0xff0000, 0xff005f, 0xff0087, 0xff00af,
                 0xff00d7, 0xff00ff, 0xff5f00, 0xff5f5f,
                 0xff5f87, 0xff5faf, 0xff5fd7, 0xff5fff,
                 0xff8700, 0xff875f, 0xff8787, 0xff87af,
                 0xff87d7, 0xff87ff, 0xffaf00, 0xffaf5f,
                 0xffaf87, 0xffafaf, 0xffafd7, 0xffafff,
                 0xffd700, 0xffd75f, 0xffd787, 0xffd7af,
                 0xffd7d7, 0xffd7ff, 0xffff00, 0xffff5f,
                 0xffff87, 0xffffaf, 0xffffd7, 0xffffff,
                 0x080808, 0x121212, 0x1c1c1c, 0x262626,
                 0x303030, 0x3a3a3a, 0x444444, 0x4e4e4e,
                 0x585858, 0x626262, 0x6c6c6c, 0x767676,
                 0x808080, 0x8a8a8a, 0x949494, 0x9e9e9e,
                 0xa8a8a8, 0xb2b2b2, 0xbcbcbc, 0xc6c6c6,
                 0xd0d0d0, 0xdadada, 0xe4e4e4, 0xeeeeee]

proc renderStringRightAligned(
  this: StatusBar,
  s: string,
  defaultColor: XftColor,
  x: int,
  leftPadding: Natural = 0
): int =
  ## Renders a string right aligned to position x.
  ## This supports ANSI CSI SGR colors by using the normal 3/4
  let str =
    if leftPadding > 0:
      s.indent(leftPadding)
    else:
      s

  var
    runeInfo: seq[(Rune, PXftFont, XGlyphInfo)]
    stringWidth, xLoc, pos: int
    color = defaultColor
    bgColor = this.bgColor
    parsingCsi = false
    parsingSgr = false
    invalidSgr = false
    sgr: seq[int]
    currentSgr: seq[Rune]

  template addSgr(): untyped =
    if currentSgr.len == 0:
      sgr.add 0
    else:
      try:
        sgr.add parseInt($currentSgr)
      except:
        invalidSgr = true
    reset currentSgr

  for rune in str.runes:
    let runeAddr = cast[PFcChar8](str[pos].unsafeAddr)
    pos += rune.size
    var foundFont = false
    for font in this.fonts:
      if rune.int32 == 27:
        parsingCsi = true
      if not parsingCsi and  XftCharExists(this.display, font, rune.FcChar32) == 1:
        var glyph: XGlyphInfo
        XftTextExtentsUtf8(this.display, font, runeAddr, rune.size, glyph.addr)
        runeInfo.add((rune, font, glyph))
        stringWidth += glyph.xOff
        foundFont = true
        break
    if rune.int32 != ord('[') and rune.int32 in 0x40..0x7E:
      parsingCsi = false
    if not foundFont:
      var glyph: XGlyphInfo
      runeInfo.add((rune, nil, glyph))

  parsingCsi = false
  xLoc = x - stringWidth
  pos = 0
  for (rune, font, glyph) in runeInfo:
    let runeAddr = cast[PFcChar8](str[pos].unsafeAddr)
    pos += rune.size
    if rune.int32 == 27:
      parsingCsi = true
      parsingSgr = false
      invalidSgr = false
      continue
    if parsingCsi:
      if parsingSgr:
        if rune.int32 != ord(';') and rune.int32 notin 0x40..0x7E:
          currentSgr.add rune
        else:
          addSgr()
      if rune.int32 == ord('['):
        parsingSgr = true
        reset sgr
        continue
    if not parsingCsi and font != nil:
      let centerY = font.ascent + (this.area.height.int - font.height) div 2
      XftDrawRect(this.draw, bgColor.addr, xLoc, 0, glyph.xOff.int, this.area.height.int)
      XftDrawStringUtf8(
        this.draw,
        color.addr,
        font,
        xLoc,
        centerY,
        runeAddr,
        rune.size
      )
      xLoc += glyph.xOff

    if parsingCsi:
      if rune.int32 in 0x40..0x7E:
        parsingCsi = false
        if parsingSgr:
          if not invalidSgr:
            var i = 0
            while i < sgr.len:
              var
                oldColor = color
                oldBgColor = bgColor
              if sgr[i] == 0:
                color = defaultColor
              elif sgr[i] >= 30 and sgr[i] <= 37:
                this.configureColor(basicColors[sgr[i] - 30], color)
              elif sgr[i] >= 40 and sgr[i] <= 47:
                this.configureColor(basicColors[sgr[i] - 40], bgColor)
              elif sgr[i] >= 90 and sgr[i] <= 97:
                this.configureColor(brightColors[sgr[i] - 90], color)
              elif sgr[i] >= 100 and sgr[i] <= 107:
                this.configureColor(brightColors[sgr[i] - 100], bgColor)
              elif sgr.len > i + 2 and sgr[i] in {38, 48} and sgr[i + 1] == 5:
                if sgr[i] == 38:
                  this.configureColor(extraColors[sgr[i + 2]], color)
                else:
                  this.configureColor(extraColors[sgr[i + 2]], bgColor)
                i += 2
              elif sgr.len > i + 4 and sgr[i] in {38, 48} and sgr[i + 1] == 2:
                if sgr[i] == 38:
                  this.configureColor((sgr[i + 2] shl 16) or (sgr[i + 3] shl 8) or sgr[i + 4], color)
                else:
                  this.configureColor((sgr[i + 2] shl 16) or (sgr[i + 3] shl 8) or sgr[i + 4], bgColor)
                i += 4
              if oldColor != color and oldColor != defaultColor:
                this.freeColor(oldColor.addr)
              if oldBgColor != bgColor and oldBgColor != this.bgColor:
                this.freeColor(oldBgColor.addr)
              inc i

  if color != defaultColor:
    this.freeColor(color.addr)
  if bgColor != this.bgColor:
    this.freeColor(bgColor.addr)

  return stringWidth

proc renderStringCentered*(
  this: StatusBar,
  str: string,
  x: int,
  color: XftColor,
  minRenderX: int = 0
) =
  ## Renders a string centered at position x.
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

type CharRenderCallback = proc(
  font: PXftFont,
  glyph: XGlyphInfo,
  rune: Rune,
  runeAddr: PFcChar8
)

proc forEachCharacter*(
  this: StatusBar,
  str: string,
  x: int,
  color: XftColor,
  characterCallback: CharRenderCallback =
    proc(
      font: PXftFont,
      glyph: XGlyphInfo,
      rune: Rune,
      runeAddr: PFcChar8
    ) = discard
): int =
  ## Returns the length of the string in pixels.
  var
    glyph: XGlyphInfo
    pos = 0
    stringWidth: int

  for rune in str.runes:
    let runeAddr = cast[PFcChar8](str[pos].unsafeAddr)
    pos += rune.size
    for font in this.fonts:
      if XftCharExists(this.display, font, rune.FcChar32) == 1:
        XftTextExtentsUtf8(this.display, font, runeAddr, rune.size, glyph.addr)
        characterCallback(font, glyph, rune, runeAddr)
        stringWidth += glyph.xOff
        break

  return stringWidth

proc renderString*(this: StatusBar, str: string, color: XftColor, startX: int): int =
  ## Renders a string at position x.
  ## Returns the length of the rendered string in pixels.
  var xLoc = startX
  let callback: CharRenderCallback =
    proc(font: PXftFont, glyph: XGlyphInfo, rune: Rune, runeAddr: PFcChar8) =
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
  return this.forEachCharacter(str, startX, color, callback)

proc renderTags(this: StatusBar): int =
  # Tag rendering layout is as follows:
  # <space><box><tag text><space><space>
  # Each <space> is the same width as the <box>

  var textXPos: int = boxWidth * 2

  for tagID, tagSettings in this.tagSettings.pairs():
    # Determine the render color.
    var
      fgColor = this.fgColor
      tagIsEmpty = true
      tagHasCurrentClient = false
      tagIsUrgent = false

    if this.selectedTags.contains(tagID):
      fgColor = this.selectionColor

    for node in this.taggedClients.clientWithTagIter(tagID):
      tagIsEmpty = false
      let client = node.value
      tagIsUrgent = tagIsUrgent or client.isUrgent
      if client == this.taggedClients.currClient:
        tagHasCurrentClient = true
        if tagIsUrgent:
          break

    let text = tagSettings.displayString
    let stringLength = this.forEachCharacter(text, textXPos, fgColor)

    if not tagIsEmpty:
      let boxXLoc = textXPos - boxWidth
      if tagIsUrgent:
        XftDrawRect(
          this.draw,
          this.urgentColor.unsafeAddr,
          boxXLoc - boxWidth,
          0,
          stringLength + boxWidth * 4,
          this.area.height.cuint
        )
      XftDrawRect(this.draw, fgColor.addr, boxXLoc, 0, 4, 4)
      if not tagHasCurrentClient:
        var bgColor = if tagIsUrgent: this.urgentColor else: this.bgColor
        XftDrawRect(this.draw, bgColor.addr, boxXLoc + 1, 1, 2, 2)

    discard this.renderString(text, fgColor, textXPos)
    textXPos += stringLength + boxWidth * 4

  return textXPos

proc renderStatus(this: StatusBar): int =
  if this.status.len > 0:
    result = this.renderStringRightAligned(
      this.status,
      this.fgColor,
      this.currentWidth - rightPadding,
      2
    )

proc renderActiveWindowTitle(
  this: StatusBar,
  minRenderX: int,
  position: WindowTitlePosition
) =
  if this.activeWindowTitle.len <= 0:
    return

  let textColor =
    if this.isMonitorSelected:
      this.selectionColor
    else:
      this.fgColor

  case position:
    of wtpLeft:
      discard this.renderString(
        this.activeWindowTitle,
        textColor,
        minRenderX
      )
    of wtpCenter:
      this.renderStringCentered(
        this.activeWindowTitle,
        this.area.width.int div 2,
        textColor,
        minRenderX
      )

proc clearBar(this: StatusBar) =
  XftDrawRect(this.draw, this.bgColor.unsafeAddr, 0, 0, this.currentWidth, this.area.height)

proc redraw*(this: StatusBar) =
  this.clearBar()
  let tagLengthPixels = this.renderTags()
  this.renderActiveWindowTitle(tagLengthPixels, this.windowTitlePosition)
  discard this.renderStatus()
  discard XSync(this.display, false)

proc setIsMonitorSelected*(this: var StatusBar, isMonitorSelected: bool, redraw: bool = true) =
  this.isMonitorSelected = isMonitorSelected
  if redraw:
    this.redraw

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

