import
  x11/[x, xlib],
  parsetoml,
  strutils,
  math,
  layout,
  ../client,
  ../area,
  ../logger,
  ../taggedclients

converter intToCint(x: int): cint = x.cint
converter intToCUint(x: int): cuint = x.cuint

const layoutName: string = "masterstack"

type
  MasterStackLayout* = ref object of Layout
    gapSize*: uint
    widthDiff*: int
    defaultWidth*: int
    outerGap*: uint
    offset: LayoutOffset
    masterSlots*: uint
    resizeStep*: uint
  MasterStackLayoutSettings* = ref object of LayoutSettings
    gapSize*: uint
    outerGap*: uint
    resizeStep*: uint
    numMasterWindows*: uint
    defaultMasterWidthPercentage*: int
  Commands = enum
    mscIncreaseMasterCount = "increasemastercount",
    mscDecreaseMasterCount = "decreasemastercount",
    mscIncreaseMasterWidth = "increasemasterwidth",
    mscDecreaseMasterWidth = "decreasemasterwidth",

proc layoutSingleClient(
  this: MasterStackLayout,
  display: PDisplay,
  client: Client,
  screenWidth: uint,
  screenHeight: uint,
  offset: LayoutOffset
)
proc layoutMultipleClients(
  this: MasterStackLayout,
  display: PDisplay,
  clients: seq[Client],
  screenWidth: uint,
  screenHeight: uint,
  offset: LayoutOffset
)

proc setDefaultWidth(this: MasterStackLayout, offset: LayoutOffset)
proc calculateClientHeight(this: MasterStackLayout, clientsInColumn: uint, screenHeight: uint): uint
proc calcRoundingErr(this: MasterStackLayout, clientsInColumn, clientHeight, screenHeight: uint): int
proc calcYPosition(
  this: MasterStackLayout,
  stackIndex,
  clientsInColumn,
  clientHeight: uint,
  roundingError: int
): uint
proc calcClientWidth(this: MasterStackLayout, screenWidth: uint): uint
func calcScreenWidth(this: MasterStackLayout, offset: LayoutOffset): int
func calcScreenHeight(this: MasterStackLayout, offset: LayoutOffset): int

method parseLayoutCommand*(this: MasterStackLayoutSettings, command: string): string =
  try:
    return $parseEnum[Commands](command.toLower)
  except:
    return ""

method populateLayoutSettings*(this: var MasterStackLayoutSettings, settingsTable: TomlTableRef) =
  if settingsTable == nil:
    this.numMasterWindows = 1
    this.gapSize = 12
    this.outerGap = 0
    this.resizeStep = 10
    this.defaultMasterWidthPercentage = 50
    return
  if settingsTable.hasKey("gapSize"):
    let gapSizeSetting = settingsTable["gapSize"]
    if gapSizeSetting.kind == TomlValueKind.Int:
      this.gapSize = max(0, gapSizeSetting.intVal).uint
    else:
      log "gapSize is not an integer value!", lvlWarn

  if settingsTable.hasKey("outerGap"):
    let outerGapSetting = settingsTable["outerGap"]
    if outerGapSetting.kind == TomlValueKind.Int:
      this.outerGap = max(0, outerGapSetting.intVal).uint
    else:
      log "outerGap is not an integer value!", lvlWarn

  if settingsTable.hasKey("resizeStep"):
    let resizeStepSetting = settingsTable["resizeStep"]
    if resizeStepSetting.kind == TomlValueKind.Int:
      if resizeStepSetting.intVal > 0:
        this.resizeStep = resizeStepSetting.intVal.uint
      else:
        log "resizeStep is not a positive integer!", lvlWarn
    else:
      log "resizeStep is not an integer value!", lvlWarn

  # Check for numMasterWindows
  if settingsTable.hasKey("numMasterWindows"):
    let numMasterWindows = settingsTable["numMasterWindows"]
    if numMasterWindows.kind != TomlValueKind.Int:
      raise newException(Exception, "Invalid numMasterWindows for tag")
    this.numMasterWindows = numMasterWindows.intVal.uint

  if settingsTable.hasKey("defaultMasterWidthPercentage"):
    let masterWidthSetting = settingsTable["defaultMasterWidthPercentage"]
    if masterWidthSetting.kind == TomlValueKind.Int:
      this.defaultMasterWidthPercentage = masterWidthSetting.intVal.int.clamp(10, 90)
      if this.defaultMasterWidthPercentage != masterWidthSetting.intVal:
        log "Invalid defaultMasterWidthPercentage, clamped to 10-90%", lvlWarn
    else:
      raise newException(Exception, "invalid defaultMasterWidthPercentage for tag")

proc increaseMasterCount(layout: Layout, _: TaggedClients) =
  MasterStackLayout(layout).masterSlots.inc

proc decreaseMasterCount(layout: Layout, _: TaggedClients) =
  var masterStackLayout = MasterStackLayout(layout)
  if masterStackLayout.masterSlots.int > 0:
    masterStackLayout.masterSlots.dec

template modWidthDiff(layout: Layout, diff: int) =
  let masterStackLayout = cast[MasterStackLayout](layout)

  if
    (diff > 0 and masterStackLayout.widthDiff < 0) or
    (diff < 0 and masterStackLayout.widthDiff > 0) or
    masterStackLayout.calcClientWidth(masterStackLayout.monitorArea.width).int - abs(masterStackLayout.widthDiff).int - abs(
        diff).int > 0:
      masterStackLayout.widthDiff += diff

proc increaseMasterWidth(layout: Layout, _: TaggedClients) =
  layout.modWidthDiff(layout.MasterStackLayout.resizeStep.int)

proc decreaseMasterWidth(layout: Layout, _: TaggedClients) =
  layout.modWidthDiff(-layout.MasterStackLayout.resizeStep.int)

method availableCommands*(this: MasterStackLayoutSettings): seq[tuple[command: string, action: proc(layout: Layout, taggedClients: TaggedClients) {.nimcall.}]] =
  result = @[
    ($mscIncreaseMasterWidth, increaseMasterWidth),
    ($mscDecreaseMasterWidth, decreaseMasterWidth),
    ($mscIncreaseMasterCount, increaseMasterCount),
    ($mscDecreaseMasterCount, decreaseMasterCount)
  ]

proc newMasterStackLayout(
  monitorArea: Area,
  gapSize: uint,
  defaultWidth: int,
  borderWidth: uint,
  masterSlots: uint,
  layoutOffset: LayoutOffset,
  resizeStep: uint,
  outerGap: uint = 0
): MasterStackLayout =
  ## Creates a new MasterStack layout.
  ## masterSlots: The number of clients allowed on the left half of the screen (traditionally 1).
  result = MasterStackLayout(
    name: layoutName,
    monitorArea: monitorArea,
    gapSize: gapSize,
    defaultWidth: defaultWidth,
    borderWidth: borderWidth,
    masterSlots: masterSlots,
    outerGap: outerGap,
    offset: layoutOffset,
    resizeStep: resizeStep
  )
  result.setDefaultWidth(layoutOffset)

method newLayout*(settings: MasterStackLayoutSettings,
    monitorArea: Area,
    borderWidth: uint,
    layoutOffset: LayoutOffset): Layout =
  newMasterStackLayout(monitorArea, settings.gapSize, settings.defaultMasterWidthPercentage, borderWidth, settings.numMasterWindows, layoutOffset, settings.outerGap, settings.resizeStep)

method updateSettings*(
    this: var MasterStackLayout,
    settings: LayoutSettings,
    monitorArea: Area,
    borderWidth: uint,
    layoutOffset: LayoutOffset) =
  let masterStackSettings = cast[MasterStackLayoutSettings](settings)
  this.monitorArea = monitorArea
  this.gapSize = masterStackSettings.gapSize
  this.defaultWidth = masterStackSettings.defaultMasterWidthPercentage
  this.borderWidth = borderWidth
  this.masterSlots = masterStackSettings.numMasterWindows
  this.outerGap = masterStackSettings.outerGap
  this.setDefaultWidth(layoutOffset)

method arrange*(
    this: MasterStackLayout,
    display: PDisplay,
    clients: seq[Client],
    offset: LayoutOffset
  ) =
  ## Aligns the clients in a master/stack fashion.
  let screenWidth = calcScreenWidth(this, offset)
  let screenHeight = calcScreenHeight(this, offset)

  if screenWidth <= 0 or screenHeight <= 0:
    log "Screen width and height must be > 0!", lvlError
    return

  let clientsToBeArranged = getClientsToBeArranged(clients)
  let clientCount = clientsToBeArranged.len
  if clientCount == 1:
    this.layoutSingleClient(display, clientsToBeArranged[0], screenWidth.uint, screenHeight.uint, offset)
  else:
    this.layoutMultipleClients(display, clientsToBeArranged, screenWidth.uint, screenHeight.uint, offset)

proc layoutSingleClient(
  this: MasterStackLayout,
  display: PDisplay,
  client: Client,
  screenWidth: uint,
  screenHeight: uint,
  offset: LayoutOffset
) =
  client.oldBorderWidth = client.borderWidth
  # Hide border if it's the only client
  if this.outerGap == 0:
    client.borderWidth = 0

  client.resize(
    display,
    this.monitorArea.x + offset.left.int + int(this.outerGap),
    this.monitorArea.y + offset.top.int + int(this.outerGap),
    max(uint 1, screenWidth - this.outerGap * 2 - client.borderWidth * 2),
    max(uint 1, screenHeight - this.outerGap * 2 - client.borderWidth * 2)
  )

proc layoutMultipleClients(
  this: MasterStackLayout,
  display: PDisplay,
  clients: seq[Client],
  screenWidth: uint,
  screenHeight: uint,
  offset: LayoutOffset
) =
  let clientCount = clients.len.uint
  let masterClientCount = min(clientCount, this.masterSlots)
  # Ensure stack size isn't negative
  let stackClientCount = max(0, clientCount.int - this.masterSlots.int).uint

  # If there are only master clients, take up all horizontal space.
  let normalClientWidth =
    if masterClientCount == clientCount or masterClientCount == 0:
      this.calcClientWidth(screenWidth) * 2
    else:
      this.calcClientWidth(screenWidth)

  let masterClientHeight = this.calculateClientHeight(masterClientCount, screenHeight)
  let stackClientHeight = this.calculateClientHeight(stackClientCount, screenHeight)

  let stackRoundingErr: int = this.calcRoundingErr(stackClientCount, stackClientHeight, screenHeight)
  let masterRoundingErr: int = this.calcRoundingErr(masterClientCount, masterClientHeight, screenHeight)

  let outerGap =
    if this.outerGap > 0:
      this.outerGap
    else:
      this.gapSize

  # TODO: widthDiff is related to masterWidth
  let stackXPos: uint =
    if masterClientCount == 0:
      outerGap
    else:
      uint math.round(screenWidth.float / 2).int + math.round(this.gapSize.float / 2).int + this.widthDiff


  let widthDiff =
    if masterClientCount == clientCount or masterClientCount == 0:
      0
    else:
      this.widthDiff

  for (i, client) in clients.pairs():
    var xPos, yPos, clientWidth, clientHeight: uint
    if i.uint < masterClientCount:
      # Master layout
      xPos = outerGap
      yPos = this.calcYPosition(i.uint, masterClientCount, masterClientHeight, masterRoundingErr)
      clientHeight = masterClientHeight
      clientWidth = uint(normalClientWidth.int + widthDiff)
    else:
      # Stack layout
      xPos = stackXPos
      let stackIndex = i.uint - masterClientCount
      yPos = this.calcYPosition(stackIndex, stackClientCount, stackClientHeight, stackRoundingErr)
      clientHeight = stackClientHeight
      clientWidth = uint(normalClientWidth.int - widthDiff)

    client.oldBorderWidth = client.borderWidth
    client.borderWidth = this.borderWidth
    client.resize(
      display,
      this.monitorArea.x + (xPos + offset.left).int,
      this.monitorArea.y + (yPos + offset.top).int,
      clientWidth,
      clientHeight
    )

proc setDefaultWidth(this: MasterStackLayout, offset: LayoutOffset) =
  let screenWidth = calcScreenWidth(this, offset)
  let pxPercent = math.round(screenWidth.float / 100).int
  this.widthDiff = (this.defaultWidth - 50) * pxPercent

proc calculateClientHeight(this: MasterStackLayout, clientsInColumn: uint, screenHeight: uint): uint =
  ## Calculates the height of a client, including borders.
  if clientsInColumn <= 0:
    return 0

  let outerGap =
    if this.outerGap > 0:
      this.outerGap
    else:
      this.gapSize

  let availableHeight =
    screenHeight.int -
      int((clientsInColumn - 1) * this.gapSize) -
        int(clientsInColumn * (this.borderWidth * 2)) -
          int(outerGap * 2)

  if availableHeight <= 0:
    return 0

  result = math.round(availableHeight.float / clientsInColumn.float).uint

proc calcRoundingErr(this: MasterStackLayout, clientsInColumn, clientHeight, screenHeight: uint): int =
  ## Calculates the overall rounding error created from diving an imperfect number of pixels.
  ## E.g. A screen with a height of 1080px cannot be evenly divided by 7 clients.
  let outerGap =
    if this.outerGap > 0:
      this.outerGap
    else:
      this.gapSize

  return
    screenHeight.int -
      int(clientsInColumn * (clientHeight + this.borderWidth * 2)) -
        int(int(this.gapSize) * int(clientsInColumn) - int(this.gapSize)) -
          int(outerGap * 2)

proc calcYPosition(
  this: MasterStackLayout,
  stackIndex,
  clientsInColumn,
  clientHeight: uint,
  roundingError: int
): uint =
  ## Calculates the y position of a client within a client stack.
  let outerGap =
    if this.outerGap > 0:
      this.outerGap
    else:
      this.gapSize

  var pos = int(outerGap) + int(stackIndex * (this.gapSize + clientHeight + this.borderWidth * 2))
  if stackIndex == clientsInColumn - 1:
     pos += roundingError

  return max(0, pos).uint

proc calcClientWidth(this: MasterStackLayout, screenWidth: uint): uint =
  ## client width per pane excluding borders & gaps
  let outerGap =
    if this.outerGap > 0:
      this.outerGap
    else:
      this.gapSize

  uint max(
    0,
    math.round(screenWidth.float / 2).int -
      (this.borderWidth * 2).int -
        int(outerGap.float) -
          math.round(this.gapSize.float * 0.5).int
  )

func calcScreenWidth(this: MasterStackLayout, offset: LayoutOffset): int = this.monitorArea.width.int - offset.left.int - offset.right.int
func calcScreenHeight(this: MasterStackLayout, offset: LayoutOffset): int = this.monitorArea.height.int - offset.top.int - offset.bottom.int
