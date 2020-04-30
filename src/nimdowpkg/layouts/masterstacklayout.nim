import
  x11 / [x, xlib],
  sets,
  math,
  layout

converter intToCint(x: int): cint = x.cint
converter intToCUint(x: int): cuint = x.cuint

const layoutName: string = "masterstack"

type MasterStackLayout* = ref object of Layout
  masterSlots*: int

proc layoutSingleWindow(
  display: PDisplay,
  window: TWindow,
  screenWidth: int,
  screenHeight: int
)
proc layoutMultipleWindows(
  this: MasterStackLayout,
  display: PDisplay,
  windows: OrderedSet[TWindow],
  screenWidth: int,
  screenHeight: int
)
proc min(x, y: int): int
proc max(x, y: int): int
proc calculateWindowHeight(this: MasterStackLayout, windowsInColumn: int, screenHeight: int): int
proc calcRoundingErr(this: MasterStackLayout, winCount, winHeight, screenHeight: int): int
proc calcYPosition(
  this: MasterStackLayout,
  stackIndex,
  winCount,
  winHeight,
  roundingError: int
): int
proc calcWindowWidth(this: MasterStackLayout, screenWidth: int): int

proc newMasterStackLayout*(
  gapSize: int, 
  borderSize: int, 
  masterSlots: int
): MasterStackLayout =
  ## Creates a new MasterStack layout.
  ## masterSlots: The number of windows allowed on the left half of the screen (traditionally 1).
  MasterStackLayout(
    name: layoutName,
    gapSize: gapSize,
    borderSize: borderSize,
    masterSlots: masterSlots
  )

method doLayout*(
    this: MasterStackLayout,
    display: PDisplay,
    windows: OrderedSet[TWindow]
  ) =
  ## Aligns the windows in a master/stack fashion.
  let screenWidth = XDisplayWidth(display, 0)
  let screenHeight = XDisplayHeight(display, 0)
  let winCount = windows.len
  if winCount == 1:
    for window in windows:
      layoutSingleWindow(display, window, screenWidth, screenHeight)
  else:
    this.layoutMultipleWindows(display, windows, screenWidth, screenHeight)

proc layoutSingleWindow(
  display: PDisplay,
  window: TWindow,
  screenWidth: int,
  screenHeight: int
  ) =
  discard XMoveResizeWindow(
    display,
    window,
    0,
    0,
    screenWidth,
    screenHeight
  )
  # Hide border if it's the only window
  discard XSetWindowBorderWidth(display, window, 0)

proc layoutMultipleWindows(
  this: MasterStackLayout,
  display: PDisplay,
  windows: OrderedSet[TWindow],
  screenWidth: int,
  screenHeight: int
) =
  let windowCount = windows.len
  let masterWinCount = min(windowCount, this.masterSlots)
  # Ensure stack size isn't negative
  let stackWinCount = max(0, windowCount - this.masterSlots)

  var winWidth = this.calcWindowWidth(screenWidth)

  let masterWinHeight = this.calculateWindowHeight(masterWinCount, screenHeight)
  let stackWinHeight = this.calculateWindowHeight(stackWinCount, screenHeight)

  let stackRoundingErr: int = this.calcRoundingErr(stackWinCount, stackWinHeight, screenHeight)
  let masterRoundingErr: int = this.calcRoundingErr(masterWinCount, masterWinHeight, screenHeight)
 
  let stackXPos = int(math.round(screenWidth / 2)) +
                  int(math.round(this.gapSize / 2))

  if windowCount == masterWinCount:
    # If there are only master windows, take up all horizontal space.
    winWidth *= 2

  var
    xPos: int
    yPos: int
    winHeight: int

  for (i, window) in windows.pairs():
    discard XSetWindowBorderWidth(display, window, this.borderSize)
    if i < masterWinCount:
      # Master layout
      xPos = this.gapSize
      yPos = this.calcYPosition(i, masterWinCount, masterWinHeight, masterRoundingErr)
      winHeight = masterWinHeight
    else:
      # Stack layout
      xPos = stackXPos
      let stackIndex = i - masterWinCount
      yPos = this.calcYPosition(stackIndex, stackWinCount, stackWinHeight, stackRoundingErr)
      winHeight = stackWinHeight

    discard XMoveResizeWindow(
      display,
      window,
      xPos,
      yPos,
      winWidth,
      winHeight
    )

proc min(x, y: int): int =
  if x < y: x else: y

proc max(x, y: int): int =
  if x > y: x else: y

proc calculateWindowHeight(this: MasterStackLayout, windowsInColumn: int, screenHeight: int): int =
  ## Calculates the height of a window (not counting its borders).
  if windowsInColumn <= 0: 0 else:
    math.round(
      (screenHeight -
       (windowsInColumn * (this.gapSize + this.borderSize * 2) + this.gapSize)) / windowsInColumn
    ).int

proc calcRoundingErr(this: MasterStackLayout, winCount, winHeight, screenHeight: int): int =
  ## Calculates the overall rounding error created from diving an imperfect number of pixels.
  ## E.g. A screen with a height of 1080px cannot be evenly divided by 7 windows.
  return (screenHeight - (this.gapSize + (winHeight + this.gapSize + this.borderSize * 2) * winCount))

proc calcYPosition(
  this: MasterStackLayout,
  stackIndex,
  winCount,
  winHeight,
  roundingError: int
): int =
  ## Calculates the y position of a window within a window stack.
  result = stackIndex * (this.gapSize + winHeight + this.borderSize * 2) + this.gapSize
  if stackIndex == winCount - 1:
     result += roundingError

proc calcWindowWidth(this: MasterStackLayout, screenWidth: int): int =
  int(math.round(screenWidth / 2)) -
    (this.borderSize * 2) -
    int(math.round(float(this.gapSize) * 1.5))

