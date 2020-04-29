import
  x11 / [x, xlib],
  sets

type Layout* = ref object of RootObj
  name*: string
  gapSize*: int
  borderSize*: int

proc newLayout*(name: string, gapSize: int, borderSize: int): Layout =
  Layout(name: name, gapSize: gapSize, borderSize: borderSize)

method doLayout*(this: Layout, display: PDisplay, windows: OrderedSet[TWindow]) {.base.} =
  echo "Not implemented for base class"

