import
  x11/xlib,
  math,
  layout,
  "../client"

converter intToCint(x: int): cint = x.cint
converter intToCUint(x: int): cuint = x.cuint

const layoutName: string = "masterstack"

type MasterStackLayout* = ref object of Layout
  masterSlots*: int

proc layoutSingleClient(
  display: PDisplay,
  client: Client,
  screenWidth: int,
  screenHeight: int
)
proc layoutMultipleClients(
  this: MasterStackLayout,
  display: PDisplay,
  clients: seq[Client],
  screenWidth: int,
  screenHeight: int
)
proc min(x, y: int): int
proc max(x, y: int): int
proc calculateClientHeight(this: MasterStackLayout, clientsInColumn: int, screenHeight: int): int
proc calcRoundingErr(this: MasterStackLayout, clientCount, clientHeight, screenHeight: int): int
proc calcYPosition(
  this: MasterStackLayout,
  stackIndex,
  clientCount,
  clientHeight,
  roundingError: int
): int
proc calcClientWidth(this: MasterStackLayout, screenWidth: int): int
proc getClientsToBeArranged(clients: seq[Client]): seq[Client]

proc newMasterStackLayout*(
  gapSize: int, 
  borderSize: int, 
  masterSlots: int
): MasterStackLayout =
  ## Creates a new MasterStack layout.
  ## masterSlots: The number of clients allowed on the left half of the screen (traditionally 1).
  MasterStackLayout(
    name: layoutName,
    gapSize: gapSize,
    borderSize: borderSize,
    masterSlots: masterSlots
  )

method arrange*(
    this: MasterStackLayout,
    display: PDisplay,
    clients: seq[Client]
  ) =
  ## Aligns the clients in a master/stack fashion.
  let screenWidth = XDisplayWidth(display, 0)
  let screenHeight = XDisplayHeight(display, 0)
  let clientsToBeArranged = getClientsToBeArranged(clients)
  let clientCount = clientsToBeArranged.len
  if clientCount == 1:
    for client in clientsToBeArranged:
      layoutSingleClient(display, client, screenWidth, screenHeight)
  else:
    this.layoutMultipleClients(display, clientsToBeArranged, screenWidth, screenHeight)

proc layoutSingleClient(
  display: PDisplay,
  client: Client,
  screenWidth: int,
  screenHeight: int
  ) =
  discard XMoveResizeWindow(
    display,
    client.window,
    0,
    0,
    screenWidth,
    screenHeight
  )
  # Hide border if it's the only client
  discard XSetWindowBorderWidth(display, client.window, 0)

proc layoutMultipleClients(
  this: MasterStackLayout,
  display: PDisplay,
  clients: seq[Client],
  screenWidth: int,
  screenHeight: int
) =
  let clientCount = clients.len
  let masterClientCount = min(clientCount, this.masterSlots)
  # Ensure stack size isn't negative
  let stackClientCount = max(0, clientCount - this.masterSlots)

  var clientWidth = this.calcClientWidth(screenWidth)

  let masterClientHeight = this.calculateClientHeight(masterClientCount, screenHeight)
  let stackClientHeight = this.calculateClientHeight(stackClientCount, screenHeight)

  let stackRoundingErr: int = this.calcRoundingErr(stackClientCount, stackClientHeight, screenHeight)
  let masterRoundingErr: int = this.calcRoundingErr(masterClientCount, masterClientHeight, screenHeight)
 
  let stackXPos = int(math.round(screenWidth / 2)) +
                  int(math.round(this.gapSize / 2))

  if clientCount == masterClientCount:
    # If there are only master clients, take up all horizontal space.
    clientWidth *= 2

  var
    xPos: int
    yPos: int
    clientHeight: int

  for (i, client) in clients.pairs():
    discard XSetWindowBorderWidth(display, client.window, this.borderSize)
    if i < masterClientCount:
      # Master layout
      xPos = this.gapSize
      yPos = this.calcYPosition(i, masterClientCount, masterClientHeight, masterRoundingErr)
      clientHeight = masterClientHeight
    else:
      # Stack layout
      xPos = stackXPos
      let stackIndex = i - masterClientCount
      yPos = this.calcYPosition(stackIndex, stackClientCount, stackClientHeight, stackRoundingErr)
      clientHeight = stackClientHeight

    discard XMoveResizeWindow(
      display,
      client.window,
      xPos,
      yPos,
      clientWidth,
      clientHeight
    )

proc min(x, y: int): int =
  if x < y: x else: y

proc max(x, y: int): int =
  if x > y: x else: y

proc calculateClientHeight(this: MasterStackLayout, clientsInColumn: int, screenHeight: int): int =
  ## Calculates the height of a client (not counting its borders).
  if clientsInColumn <= 0: 0 else:
    math.round(
      (screenHeight -
       (clientsInColumn * (this.gapSize + this.borderSize * 2) + this.gapSize)) / clientsInColumn
    ).int

proc calcRoundingErr(this: MasterStackLayout, clientCount, clientHeight, screenHeight: int): int =
  ## Calculates the overall rounding error created from diving an imperfect number of pixels.
  ## E.g. A screen with a height of 1080px cannot be evenly divided by 7 clients.
  return (screenHeight - (this.gapSize + (clientHeight + this.gapSize + this.borderSize * 2) * clientCount))

proc calcYPosition(
  this: MasterStackLayout,
  stackIndex,
  clientCount,
  clientHeight,
  roundingError: int
): int =
  ## Calculates the y position of a client within a client stack.
  result = stackIndex * (this.gapSize + clientHeight + this.borderSize * 2) + this.gapSize
  if stackIndex == clientCount - 1:
     result += roundingError

proc calcClientWidth(this: MasterStackLayout, screenWidth: int): int =
  int(math.round(screenWidth / 2)) -
    (this.borderSize * 2) -
    int(math.round(float(this.gapSize) * 1.5))

proc getClientsToBeArranged(clients: seq[Client]): seq[Client] =
  ## Finds all clients that should be arranged in the layout.
  ## Some windows are excluded, such as fullscreen windows.
  for client in clients:
    if not client.isFullscreen and not client.isFloating:
      result.add(client)

