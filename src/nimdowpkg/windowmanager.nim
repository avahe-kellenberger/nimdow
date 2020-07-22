import
  x11 / [x, xlib, xutil, xatom],
  math,
  sugar,
  options,
  utils/optionutils,
  tables,
  client,
  xatoms,
  monitor,
  statusbar,
  tag,
  area,
  config/configloader,
  event/xeventmanager,
  layouts/masterstacklayout,
  keys/keyutils

converter intToFloat(x: int): float = x.float
converter intToCint(x: int): cint = x.cint
converter intToCUint(x: int): cuint = x.cuint
converter cintToUint(x: cint): uint = x.uint
converter cintToCUint(x: cint): cuint = x.cuint
converter intToCUchar(x: int): cuchar = x.cuchar
converter clongToCUlong(x: clong): culong = x.culong
converter toXBool(x: bool): XBool = x.XBool
converter toBool(x: XBool): bool = x.bool

# NOTES: 0 in C is false, all other ints are true.

const
  wmName = "nimdow"
  tagCount = 9
  minimumUpdateInterval = math.round(1000 / 60).int
  broken = "<No Name>"

var
  display: PDisplay
  sText: string # ?
  screen: int
  screenWidth, screenHeight: int
  barHeight, barWidth: int = 0
  enableGaps: bool = true
  lrpad: int # sum of left and right padding for text
  numlockMask: uint = 0
  running: bool = true
  monitors, selectedMonitor: Monitor
  root, wmCheckWindow: Window
  useARGB: bool = false
  visual: PVisual
  depth: int
  colormap: Colormap

# config.h vars
  respectResizeHints: bool = false

type
  Monitor = ref object of RootObj
    screenX, screenY, screenWidth, screenHeight: int
    layoutSymbol: string
    # Scale between left and right of screen. Need a better name.
    mFactor: float
    numMasterWindows: int
    # Monitor index?
    num: int
    barY: int
    windowAreaX, windowAreaY, windowAreaWidth, windowAreaHeight: int
    gapInnerHorizontal, gapInnerVertical: int
    gapOuterHorizontal, gapOuterVertical: int
    selectedTags: uint
    selectedLayout: uint
    tagset: array[2, uint]
    showBar, topBar: bool
    # Singlar client because they are linked internally
    clients: Client
    selectedClient: Client
    clientStack: Client
    next: Monitor
    bar: Window
    layout: Layout
    pertag: Pertag

  Client = ref object of RootObj
    x, y, width, height: int
    next: Client
    monitor: Monitor
    window: Window
    tags: uint
    borderWidth, oldBorderWidth: uint

    minAspectRatio, maxAspectRatio: float

    # Dimensions
    baseWidth, baseHeight: int
    minWidth, minHeight: int
    maxWidth, maxHeight: int
    # Increment, I think
    incWidth, incHeight: int

    isFixed, isCentered,
      isFloating, isUrgent,
      neverFocus, isFullscreen,
      needsResize: bool

    oldState: int

  Layout = ref object of RootObj

  Pertag = ref object of RootObj
    currentTag, previousTag: uint
    numMasterWindows: array[tagCount, int]
    mFactors: array[tagCount, float]
    selectedLayouts: array[tagCount, uint]
    showBars: array[tagCount, bool]

proc
applyRules(client: var Client) =
  # We don't care about dwm rules currently
  discard

proc
applySizeHints(client: Client, x, y, width, height: var int, interact: bool): bool =
  var
    baseIsMin: bool
    monitor: Monitor = client.monitor
  # Set minimum possible
  width = max(1, width)
  height = max(1, height)

  if interact:
    if x > screenWidth:
      x = screenWidth - client.width
    if y > screenHeight:
      y = screenHeight - client.height
    if (x + width + 2 * client.borderWidth) < 0:
      x = 0
    if (y + height + 2 * client.borderWidth) < 0:
      y = 0
  else:
    if x >= (monitor.windowAreaX + monitor.windowAreaWidth):
      x = monitor.windowAreaX + monitor.windowAreaWidth - client.width
    if y >= (monitor.windowAreaY + monitor.windowAreaHeight):
      y = monitor.windowAreaY + monitor.windowAreaHeight - client.height
    if (x + width + 2 * client.borderWidth) <= monitor.windowAreaX:
      x = monitor.windowAreaX
    if (y + height + 2 * client.borderWidth) <= monitor.windowAreaY:
      y = monitor.windowAreaY

  # TODO: Why?
  if height < barHeight:
    height = barHeight
  if width < barHeight:
    width = barHeight

  if respectResizeHints or client.isFloating:
    baseIsMin = client.baseWidth == client.minWidth and client.baseHeight == client.minHeight

    if not baseIsMin:
      width.dec(client.baseWidth)
      height.dec(client.baseHeight)

    # Adjust for aspect limits
    if client.minAspectRatio > 0 and client.maxAspectRatio > 0:
      if client.maxAspectRatio < (width / height):
        width = (height * client.maxAspectRatio + 0.5).int
      elif client.minAspectRatio < (height / width):
        height = (width * client.minAspectRatio + 0.5).int

    # Increment calculation requires this
    if baseIsMin:
      width.dec(client.baseWidth)
      height.dec(client.baseHeight)

    # Adjust for increment value
    if client.incWidth != 0:
      width -= width mod client.incWidth
    if client.incHeight != 0:
      height -= height mod client.incHeight

    # Restore base dimenons
    width = max(width + client.baseWidth, client.minWidth)
    height = max(height + client.baseHeight, client.minHeight)
    if client.maxWidth != 0:
      width = min(width, client.maxWidth)
    if client.maxHeight != 0:
      height = min(height, client.maxHeight)

    return x != client.x or
           y != client.y or
           width != client.width or
           height != client.height

