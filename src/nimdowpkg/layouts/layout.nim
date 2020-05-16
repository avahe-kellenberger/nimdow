import
  x11/xlib,
  "../client"

type Layout* = ref object of RootObj
  name*: string
  gapSize*: int
  borderWidth*: int

proc newLayout*(name: string, gapSize: int, borderWidth: int): Layout =
  Layout(name: name, gapSize: gapSize, borderWidth: borderWidth)

method arrange*(this: Layout, display: PDisplay, clients: seq[Client]) {.base.} =
  echo "Not implemented for base class"

