import
  x11/xlib,
  "../client"

type Layout* = ref object of RootObj
  name*: string
  gapSize*: int
  borderSize*: int

proc newLayout*(name: string, gapSize: int, borderSize: int): Layout =
  Layout(name: name, gapSize: gapSize, borderSize: borderSize)

method arrange*(this: Layout, display: PDisplay, clients: seq[Client]) {.base.} =
  echo "Not implemented for base class"

