import
  x11/xlib,
  ../client,
  ../area

type
  Layout* = ref object of RootObj
    name*: string
    monitorArea*: Area
    gapSize*: uint
    borderWidth*: uint
    masterSlots*: uint
  LayoutOffset* = tuple[top, left, bottom, right: uint]
  LayoutSettings* = ref object of RootObj

proc newLayout*(name: string, monitorArea: Area, gapSize: uint, borderWidth: uint): Layout =
  Layout(name: name, gapSize: gapSize, borderWidth: borderWidth)

method arrange*(this: Layout, display: PDisplay, clients: seq[Client], offset: LayoutOffset) {.base.} =
  echo "Not implemented for base class"

method parseLayoutCommand*(this: LayoutSettings, command: string): string {.base.} =
  echo "Not implemented for base class"

method availableCommands*(this: LayoutSettings): seq[tuple[command: string, action: proc(layout: Layout) {.nimcall.}]] =
  echo "Not implemented for base class"

