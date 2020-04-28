import
  hashes,
  layouts/layout

type Tag* = ref object
  id*: int
  layout*: Layout

proc hash*(this: Tag): Hash = !$Hash(this.id) 

