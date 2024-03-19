import ../area

type
  Layout* = ref object of RootObj
    name*: string
    monitorArea*: Area
    borderWidth*: uint
  LayoutOffset* = tuple[top, left, bottom, right: uint]

