import
  options,
  hashes,
  x11/x,
  layouts/layout

type Tag* = ref object
  id*: int
  layout*: Layout
  selectedWin*: Option[TWindow]
  previouslySelectedWin*: Option[TWindow]

proc newTag*(id: int, layout: Layout): Tag =
  Tag(
    id: id,
    layout: layout,
    selectedWin: none(TWindow),
    previouslySelectedWin: none(TWindow)
  )

proc setSelectedWindow*(this: Tag, window: TWindow) =
  this.previouslySelectedWin = this.selectedWin
  this.selectedWin = window.option

proc hash*(this: Tag): Hash = !$Hash(this.id) 

