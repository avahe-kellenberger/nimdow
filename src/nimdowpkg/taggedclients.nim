import
  x11/x,
  lists,
  listutils,
  sets,
  sequtils

import
  client,
  tag

export tag, client, lists, sets

type
  ClientNode* = DoublyLinkedNode[Client]

  TaggedClients* = ref object
    clients*: DoublyLinkedList[Client]
    # TODO: Needs a better name.
    # This is the order of clients based on selection order, oldest to newest.
    clientSelection*: DoublyLinkedList[Client]

    tags*: seq[Tag]
    selectedTags*: OrderedSet[TagID]

proc newTaggedClients*(tagCount: int): TaggedClients = TaggedClients()

template currClientNode*(this: TaggedClients): DoublyLinkedNode[Client] =
  this.clientSelection.tail

template currClient*(this: TaggedClients): Client =
  let node = this.currClientNode
  if node != nil:
    node.value
  else:
    nil

template withSomeCurrClient*(this: TaggedClients, client, body: untyped) =
  ## Executes `body` if `this.currClient != nil`
  if this.currClient != nil:
    var client: Client = this.currClient
    body

proc getFirstSelectedTag*(this: TaggedClients): Tag =
  ## Gets the first selected tag,
  ## or `nil` if to tags are selected.
  for tag in this.tags.items:
    result = tag
    break

iterator currClientsIter*(this: TaggedClients): ClientNode {.inline, closure.} =
  ## Iterates over clients in stack order.
  for node in this.clients.nodes:
    if node.value.tagIDs.anyIt(this.selectedTags.contains(it)):
      yield node

iterator currClientsReverseIter*(this: TaggedClients): ClientNode {.inline, closure.} =
  ## Iterates over clients in reverse stack order.
  for node in this.clients.reverseNodes:
    if node.value.tagIDs.anyIt(this.selectedTags.contains(it)):
      yield node

proc findCurrentClients*(this: TaggedClients): seq[Client] =
  for node in this.currClientsIter:
    result.add(node.value)

proc currClientsContains*(this: TaggedClients, client: Client): bool =
  for node in this.currClientsIter:
    if node.value == client:
      return true
  return false

proc currClientsContains*(this: TaggedClients, window: Window): bool =
  for node in this.currClientsIter:
    if node.value != nil and node.value.window == window:
      return true
  return false

proc contains*(this: TaggedClients, window: Window): bool =
  for client in this.clients.items:
    if client != nil and client.window == window:
      return true
  return false

iterator clientWithTagIter*(this: TaggedClients, tagID: TagID): ClientNode {.inline, closure.} =
  for node in this.clients.nodes:
    if node.value.tagIDs.contains(tagID):
      yield node

iterator currClientsSelectionNewToOldIter*(this: TaggedClients): ClientNode {.inline, closure.} =
  ## Iterates over clients in order of selection,
  ## from most recent to least recent.
  for node in this.clientSelection.reverseNodes:
    if node.value.tagIDs.anyIt(this.selectedTags.contains(it)):
      yield node

iterator currClientsSelectionOldToNewIter*(this: TaggedClients): ClientNode {.inline, closure.} =
  ## Iterates over clients in order of selection,
  ## from least recent to most recent.
  for node in this.clientSelection.nodes:
    if node.value.tagIDs.anyIt(this.selectedTags.contains(it)):
      yield node


