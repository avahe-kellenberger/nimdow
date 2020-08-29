import
  hashes,
  layouts/layout,
  client

type Tag* = ref object
  id*: int
  layout*: Layout
  selectedClient*: Client
  previouslySelectedClient*: Client

proc newTag*(id: int, layout: Layout): Tag =
  Tag(
    id: id,
    layout: layout,
    selectedClient: nil,
    previouslySelectedClient: nil
  )

proc isSelectedClient*(this: Tag, client: Client): bool =
  this.selectedClient != nil and this.selectedClient == client

proc isPreviouslySelectedClient*(this: Tag, client: Client): bool =
  this.previouslySelectedClient != nil and this.previouslySelectedClient == client

proc setSelectedClient*(this: Tag, client: Client) =
  if this.selectedClient == nil or client != this.selectedClient:
    this.previouslySelectedClient = this.selectedClient
    this.selectedClient = client

proc clearSelectedClient*(this: Tag, client: Client) =
  ## If selectedClient and/or previouslySelectedClient is equal to `client`,
  ## the respective fields will be set to nil.
  if this.selectedClient != nil and this.selectedClient == client:
    this.selectedClient = nil

  if this.previouslySelectedClient != nil and this.previouslySelectedClient == client:
    this.previouslySelectedClient = nil

  if this.selectedClient == nil and this.previouslySelectedClient != nil:
    this.selectedClient = this.previouslySelectedClient

proc hash*(this: Tag): Hash = !$Hash(this.id)

