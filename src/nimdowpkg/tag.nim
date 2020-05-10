import
  options,
  hashes,
  layouts/layout,
  client

type Tag* = ref object
  id*: int
  layout*: Layout
  selectedClient*: Option[Client]
  previouslySelectedClient*: Option[Client]

proc newTag*(id: int, layout: Layout): Tag =
  Tag(
    id: id,
    layout: layout,
    selectedClient: none(Client),
    previouslySelectedClient: none(Client)
  )

proc setSelectedClient*(this: Tag, client: Client) =
  if this.selectedClient.isNone or client != this.selectedClient.get():
    this.previouslySelectedClient = this.selectedClient
    this.selectedClient = client.option

proc hash*(this: Tag): Hash = !$Hash(this.id) 

