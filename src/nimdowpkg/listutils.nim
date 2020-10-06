import lists

export lists

iterator reverseNodes*[T](L: SomeLinkedList[T]): SomeLinkedNode[T] {.inline, closure.} =
  var it = L.tail
  while it != nil:
    yield it
    it = it.prev

iterator reverseItems*[T](L: SomeLinkedList[T]): T {.inline, closure.} =
  for node in L.reverseNodes:
    yield node.value

proc swap*[T](L: DoublyLinkedList[T], a, b: var DoublyLinkedNode[T]) =
  let temp = a.value
  a.value = b.value
  b.value = temp

proc len*[T](L: DoublyLinkedList[T]): int =
  for n in L:
    result.inc

