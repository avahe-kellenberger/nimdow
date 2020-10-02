import
  hashes,
  layouts/layout

const tagCount* = 9

type
  TagID* = 1..tagCount
  Tag* = ref object
    id*: TagID
    layout*: Layout

proc newTag*(id: TagID, layout: Layout): Tag =
  Tag(
    id: id,
    layout: layout
  )

proc hash*(this: Tag): Hash = !$Hash(this.id)

