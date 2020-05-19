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

proc isSelectedClient*(this: Tag, client: Client): bool =
  this.selectedClient.isSome and this.selectedClient.get == client

proc isPreviouslySelectedClient*(this: Tag, client: Client): bool =
  this.previouslySelectedClient.isSome and this.previouslySelectedClient.get == client

proc setSelectedClient*(this: Tag, client: Client) =
  if this.selectedClient.isNone or client != this.selectedClient.get():
    this.previouslySelectedClient = this.selectedClient
    this.selectedClient = client.option

proc clearSelectedClient*(this: Tag, client: Client) =
  ## If selectedClient and/or previouslySelectedClient
  ## is equal to `client`, the respective fields will be
  ## set to none(Client).
  if this.selectedClient.isSome() and this.selectedClient.get() == client:
    this.selectedClient = none(Client)

  if this.previouslySelectedClient.isSome() and this.previouslySelectedClient.get() == client:
    this.previouslySelectedClient = none(Client)

  if this.selectedClient.isNone and this.previouslySelectedClient.isSome:
    this.setSelectedClient(this.previouslySelectedClient.get)

proc hash*(this: Tag): Hash = !$Hash(this.id) 

