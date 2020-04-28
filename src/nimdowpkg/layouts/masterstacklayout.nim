import
  x11 / [x, xlib],
  sets,
  math,
  layout

converter intToCint(x: int): cint = x.cint
converter intToCUint(x: int): cuint = x.cuint
converter cintToCUint(x: cint): cuint = x.cuint

type MasterStackLayout* = ref object of Layout

method doLayout*(this: MasterStackLayout, display: PDisplay, windows: OrderedSet[TWindow]) =
  ## Aligns the windows in a master/stack fashion.
  # TODO: This needs cleanup after the algorithm is refined
  let screenWidth = XDisplayWidth(display, 0)
  let screenHeight = XDisplayHeight(display, 0)
  let windowCount = windows.len
  if windowCount == 1:
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
  else:
    let stackSize = windowCount - 1
    let height = int(math.round((screenHeight - ((stackSize + 1) * this.gapSize)) / stackSize))
    let roundingErr: int = screenHeight - (this.gapSize + (height + this.gapSize) * stackSize)
    for (i, window) in windows.pairs():
      discard XSetWindowBorderWidth(display, window, this.borderSize)
      # Layout master/stack layout
      if i == 0:
        discard XMoveResizeWindow(
          display,
          window,
          this.gapSize,
          this.gapSize,
          int(math.round(screenWidth / 2)) - (this.borderSize * 2) - int(math.round(float(this.gapSize) * 1.5)),
          screenHeight - (this.gapSize + this.borderSize) * 2
        )  
      else:
        var yPos = height * (i - 1) + this.gapSize * i
        if i == stackSize:
          echo "Adding rounding error on ", i, ": ", roundingErr
          yPos += roundingErr
        discard XMoveResizeWindow(
          display,
          window,
          int(math.round(screenWidth / 2)) + int(math.round(this.gapSize / 2)),
          yPos,
          int(math.round(screenWidth / 2)) - (this.gapSize + this.borderSize) * 2,
          height - this.borderSize * 2
        )

