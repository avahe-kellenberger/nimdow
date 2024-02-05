import
  x11/xlib,
  ../client,
  ../area,
  layoutsettings

export layoutsettings

type
  Layout* = ref object of RootObj
    name*: string
    monitorArea*: Area
    gapSize*: uint
    borderWidth*: uint
    masterSlots*: uint
  LayoutOffset* = tuple[top, left, bottom, right: uint]

method newLayout*(settings: LayoutSettings,
  monitorArea: Area,
  defaultWidth: int,
  borderWidth: uint,
  masterSlots: uint,
  layoutOffset: LayoutOffset): Layout {.base.} =
  echo "newLayout not implemented for base class"

method updateSettings*(
  this: var Layout,
  settings: LayoutSettings,
  monitorArea: Area,
  defaultWidth: int,
  borderWidth: uint,
  masterSlots: uint,
  layoutOffset: LayoutOffset) {.base.} =
  echo "updateSettings not implemented for base class"

method arrange*(this: Layout, display: PDisplay, clients: seq[Client], offset: LayoutOffset) {.base.} =
  echo "arrange not implemented for base class"

method availableCommands*(this: LayoutSettings): seq[tuple[command: string, action: proc(layout: Layout) {.nimcall.}]] =
  echo "availableCommands not implemented for base class"
