import
  x11 / [x, xlib],
  sets

type Layout* = ref object of RootObj
  name*: string
  gapSize*: int
  borderSize*: int

method doLayout(this: Layout, display: PDisplay, windows: OrderedSet[TWindow]) {.base.} =
  echo "Not implemented for base class"

