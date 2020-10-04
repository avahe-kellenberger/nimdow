import
  lists,
  sets

import
  client,
  tag

export tag, client, lists, sets

type
  TaggedClients* = ref object
    clients*: DoublyLinkedList[Client]
    # TODO: Needs a better name.
    # This is the order of clients based on selection order, oldest to newest.
    clientSelection*: DoublyLinkedList[Client]

    tags*: seq[Tag]
    selectedTags*: OrderedSet[TagID]

proc newTaggedClients*(tagCount: int): TaggedClients = discard
