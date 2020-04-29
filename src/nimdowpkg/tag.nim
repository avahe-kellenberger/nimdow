import
  hashes,
  layouts/layout

type Tag* = ref object
  id*: int
  layout*: Layout

proc newTag*(id: int, layout: Layout): Tag =
  Tag(id: id, layout: layout)

proc hash*(this: Tag): Hash = !$Hash(this.id) 

