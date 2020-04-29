import
  x11 / [x, xlib],
  sets,
  math,
  layout

converter intToCint(x: int): cint = x.cint
converter intToCUint(x: int): cuint = x.cuint

const layoutName: string = "masterstack"

type MasterStackLayout* = ref object of Layout
  masterSlots*: uint

proc layoutSingleWindow(
  display: PDisplay,
  windows: OrderedSet[TWindow],
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
  masterSlots: uint
): MasterStackLayout =
  ## Creates a new MasterStack layout.
  ## masterSlots: The number of windows allowed on the left half of the screen (typically 1).
  MasterStackLayout(
    name: layoutName,
    gapSize: gapSize,
    borderSize: borderSize,
    masterSlots: masterSlots
  )

method doLayout*(this: MasterStackLayout, display: PDisplay, windows: OrderedSet[TWindow]) =
  ## Aligns the windows in a master/stack fashion.
  # TODO: This needs cleanup after the algorithm is refined
  echo this.masterSlots
  let screenWidth = XDisplayWidth(display, 0)
  let screenHeight = XDisplayHeight(display, 0)
  let windowCount = windows.len
  if windowCount == 1:
    layoutSingleWindow(display, windows, screenWidth, screenHeight)
  else:
    this.layoutMultipleWindows(display, windows, screenWidth, screenHeight)

proc layoutSingleWindow(
  display: PDisplay,
  windows: OrderedSet[TWindow],
  screenWidth: int,
  screenHeight: int
  ) =
  for window in windows.items:
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
  let stackSize = windowCount - 1
  let windowWidth = int(math.round(screenWidth / 2)) - (this.borderSize * 2) - int(math.round(float(this.gapSize) * 1.5))
  let height = int(math.round((screenHeight - ((stackSize + 1) * this.gapSize)) / stackSize))
  let roundingErr: int = screenHeight - (this.gapSize + (height + this.gapSize) * stackSize)
  for (i, window) in windows.pairs():
    discard XSetWindowBorderWidth(display, window, this.borderSize)
    # Layout master/stack layout
    # TODO: Handle multiple master windows.
    # We can use the same algorithm for both, just change the X position
    # based on i < (this.masterSlots - 1)
    if i == 0:
      # Layout left window
      discard XMoveResizeWindow(
        display,
        window,
        this.gapSize,
        this.gapSize,
        windowWidth,
        screenHeight - (this.gapSize + this.borderSize) * 2
      )  
    else:
      var yPos = height * (i - 1) + this.gapSize * i
      if i == stackSize:
        echo "Adding rounding error on ", i, ": ", roundingErr
        # NOTE: We are getting rounding errors larger than 1. Offset per window?
        yPos += roundingErr
      discard XMoveResizeWindow(
        display,
        window,
        int(math.round(screenWidth / 2)) + int(math.round(this.gapSize / 2)),
        yPos,
        windowWidth,
        height - this.borderSize * 2
      )

