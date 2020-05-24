import
  x11/xlib,
  math,
  layout,
  "../client",
  "../area"

converter intToCint(x: int): cint = x.cint
converter intToCUint(x: int): cuint = x.cuint

const layoutName: string = "masterstack"

type MasterStackLayout* = ref object of Layout
  masterSlots*: uint

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

proc calculateClientHeight(this: MasterStackLayout, clientsInColumn: uint, screenHeight: uint): uint
proc calcRoundingErr(this: MasterStackLayout, clientCount, clientHeight, screenHeight: uint): int
proc calcYPosition(
  this: MasterStackLayout,
  stackIndex,
  clientCount,
  clientHeight: uint,
  roundingError: int
): uint
proc calcClientWidth(this: MasterStackLayout, screenWidth: uint): uint
proc getClientsToBeArranged(clients: seq[Client]): seq[Client]

proc newMasterStackLayout*(
  monitorArea: Area,
  gapSize: uint, 
  borderWidth: uint, 
  masterSlots: uint
): MasterStackLayout =
  ## Creates a new MasterStack layout.
  ## masterSlots: The number of clients allowed on the left half of the screen (traditionally 1).
  MasterStackLayout(
    name: layoutName,
    monitorArea: monitorArea,
    gapSize: gapSize,
    borderWidth: borderWidth,
    masterSlots: masterSlots
  )

method arrange*(
    this: MasterStackLayout,
    display: PDisplay,
    clients: seq[Client],
    offset: LayoutOffset
  ) =
  ## Aligns the clients in a master/stack fashion.
  let screenWidth = this.monitorArea.width.int - offset.left.int - offset.right.int
  let screenHeight = this.monitorArea.height.int - offset.top.int - offset.bottom.int

  if screenWidth <= 0 or screenHeight <= 0:
    echo "Screen width and height must be > 0!"
    return

  let clientsToBeArranged = getClientsToBeArranged(clients)
  let clientCount = clientsToBeArranged.len
  if clientCount == 1:
    for client in clientsToBeArranged:
      layoutSingleClient(this, display, client, screenWidth.uint, screenHeight.uint, offset)
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
  discard XMoveResizeWindow(
    display,
    client.window,
    this.monitorArea.x + offset.left.cint,
    this.monitorArea.y + offset.top.cint,
    screenWidth.cuint,
    screenHeight.cuint
  )
  # Hide border if it's the only client
  discard XSetWindowBorderWidth(display, client.window, 0)

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
  let clientWidth = if masterClientCount == clientCount or masterClientCount == 0: 
    this.calcClientWidth(screenWidth) * 2 else:
      this.calcClientWidth(screenWidth)

  let masterClientHeight = this.calculateClientHeight(masterClientCount, screenHeight)
  let stackClientHeight = this.calculateClientHeight(stackClientCount, screenHeight)

  let stackRoundingErr: int = this.calcRoundingErr(stackClientCount, stackClientHeight, screenHeight)
  let masterRoundingErr: int = this.calcRoundingErr(masterClientCount, masterClientHeight, screenHeight)
 
  let stackXPos: uint =
    if masterClientCount == 0:
      this.gapSize else:
        math.round(screenWidth.float / 2).uint + math.round(this.gapSize.float / 2).uint

  for (i, client) in clients.pairs():
    var xPos, yPos, clientHeight: uint
    discard XSetWindowBorderWidth(display, client.window, this.borderWidth.cuint)
    if i.uint < masterClientCount:
      # Master layout
      xPos = this.gapSize
      yPos = this.calcYPosition(i.uint, masterClientCount, masterClientHeight, masterRoundingErr)
      clientHeight = masterClientHeight
    else:
      # Stack layout
      xPos = stackXPos
      let stackIndex = i.uint - masterClientCount
      yPos = this.calcYPosition(stackIndex, stackClientCount, stackClientHeight, stackRoundingErr)
      clientHeight = stackClientHeight

    discard XMoveResizeWindow(
      display,
      client.window,
      this.monitorArea.x + (xPos + offset.left).cint,
      this.monitorArea.y + (yPos + offset.top).cint,
      clientWidth.cuint,
      clientHeight.cuint
    )

proc calculateClientHeight(this: MasterStackLayout, clientsInColumn: uint, screenHeight: uint): uint =
  ## Calculates the height of a client (not counting its borders).
  if clientsInColumn <= 0:
    return 0
  else:
    let availableHeight: int = screenHeight.int - (clientsInColumn * (this.gapSize + this.borderWidth * 2) + this.gapSize).int
    if availableHeight <= 0:
      return 0
    return math.round(availableHeight.float / clientsInColumn.float).uint

proc calcRoundingErr(this: MasterStackLayout, clientCount, clientHeight, screenHeight: uint): int =
  ## Calculates the overall rounding error created from diving an imperfect number of pixels.
  ## E.g. A screen with a height of 1080px cannot be evenly divided by 7 clients.
  return (screenHeight.int - (this.gapSize + (clientHeight + this.gapSize + this.borderWidth * 2) * clientCount).int)

proc calcYPosition(
  this: MasterStackLayout,
  stackIndex,
  clientCount,
  clientHeight: uint,
  roundingError: int
): uint =
  ## Calculates the y position of a client within a client stack.
  var pos = (stackIndex * (this.gapSize + clientHeight + this.borderWidth * 2) + this.gapSize).int
  if stackIndex == clientCount - 1:
     pos += roundingError
  return max(0, pos).uint

proc calcClientWidth(this: MasterStackLayout, screenWidth: uint): uint =
  max(0, math.round(screenWidth.float / 2).int - (this.borderWidth * 2).int - math.round(this.gapSize.float * 1.5).int).uint

proc getClientsToBeArranged(clients: seq[Client]): seq[Client] =
  ## Finds all clients that should be arranged in the layout.
  ## Some windows are excluded, such as fullscreen windows.
  for client in clients:
    if not client.isFullscreen and not client.isFloating:
      result.add(client)

