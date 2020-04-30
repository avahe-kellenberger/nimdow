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

proc newMasterStackLayout*(
  gapSize: int, 
  borderSize: int, 
  masterSlots: int
): MasterStackLayout =
  ## Creates a new MasterStack layout.
  ## masterSlots: The number of windows allowed on the left half of the screen (typically 1).
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
  let windowCount = windows.len
  if windowCount == 1:
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

#[proc calcRoundingErr(winCount, screenHeight, gapSize, borderSize: int): int =
  let winHeight: int = calcWinHeight(gapSize, borderSize, winCount, screenHeight)
  return (screenHeight - (gapSize + (winHeight + gapSize + borderSize * 2) * winCount))]#

proc layoutMultipleWindows(
  this: MasterStackLayout,
  display: PDisplay,
  windows: OrderedSet[TWindow],
  screenWidth: int,
  screenHeight: int
) =
  let windowCount = windows.len
  # Ensure stack size isn't negative
  let stackSize = max(0, windowCount - this.masterSlots)
  let windowWidth = int(math.round(screenWidth / 2)) -
                    (this.borderSize * 2) -
                    int(math.round(float(this.gapSize) * 1.5))

  let masterWindowHeight = this.calculateWindowHeight(min(windowCount, this.masterSlots), screenHeight)
  let stackWindowHeight = this.calculateWindowHeight(stackSize, screenHeight)

  # NOTE: We are getting rounding errors larger than 1. Offset per window?
  # We also need to offset the master area.
  let stackRoundingErr: int =
    screenHeight -
    (this.gapSize + 
       (stackWindowHeight + this.gapSize + this.borderSize * 2) *
     stackSize)

  let masterRoundingErr: int =
    screenHeight -
    (this.gapSize + 
       (masterWindowHeight + this.gapSize + this.borderSize * 2) *
     this.masterSlots)
 
  echo "Adding rounding error on ", stackSize, ": ", stackRoundingErr

  let stackXPos = int(math.round(screenWidth / 2)) + int(math.round(this.gapSize / 2))

  for (i, window) in windows.pairs():
    discard XSetWindowBorderWidth(display, window, this.borderSize)
    if i < this.masterSlots:
      # Master layout
      var yPos = i * (this.gapSize + masterWindowHeight + this.borderSize * 2) + this.gapSize
      if i == this.masterSlots - 1:
        yPos += masterRoundingErr
      discard XMoveResizeWindow(
        display,
        window,
        this.gapSize,
        yPos,
        windowWidth,
        masterWindowHeight
      )  
    else:
      # Stack layout
      let stackIndex = i - this.masterSlots
      var yPos = stackIndex * (this.gapSize + stackWindowHeight + this.borderSize * 2) + this.gapSize

      if stackIndex == stackSize - 1:
        # Offset the last window by the rounding error.
        yPos += stackRoundingErr
      discard XMoveResizeWindow(
        display,
        window,
        stackXPos,
        yPos,
        windowWidth,
        stackWindowHeight
      )

