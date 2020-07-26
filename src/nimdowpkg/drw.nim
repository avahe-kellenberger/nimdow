import x11 / [x, xlib, xft]

type
  Drw* = ref object of RootObj
    display: PDisplay
    width, height: uint
    screen: int
    root: Window
    visual: PVisual
    depth: uint
    colorMap: Colormap
    drawable: Drawable
    graphicsContext: GContext
    scheme: PXftColor
    fonts: PFont

  Font* = object
    display: PDisplay
    height: uint
    xftFont: XftFont
    next: PFont
  PFont* = ptr Font

proc fontsetGetWidth*(this: Drw, text: string): uint
proc text*(
  this: Drw,
  x,
  y: int,
  width,
  height,
  lpad: uint,
  text: string,
  invert: bool
): uint

proc newDrw*(display: PDisplay, root: Window): Drw =
  Drw(display: display, root: root)

proc fontsetGetWidth*(this: Drw, text: string): uint =
  if this.isNil or this.fonts.isNil or text.len == 0:
    return 0
  return this.text(0, 0, 0, 0, 0, text, false)

proc resize*(this: Drw, screenWidth, barHeight: int) =
  discard

proc text*(
  this: Drw,
  x,
  y: int,
  width,
  height,
  lpad: uint,
  text: string,
  invert: bool
): uint =
  # TODO
  return 0

