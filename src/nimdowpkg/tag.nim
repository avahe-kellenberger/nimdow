import
  hashes,
  taginfo,
  layouts/layout

export taginfo

type
  Tag* = ref object
    id*: TagID
    layout*: Layout

proc newTag*(id: TagID, layout: Layout): Tag =
  Tag(
    id: id,
    layout: layout
  )

proc hash*(this: Tag): Hash = !$Hash(this.id)

