# Helper procs that don't really fit anywhere.
# Should move these somewhere appropriate.
proc isInRange*[T](arr: openArray[T], index: int): bool {.inline.} =
  return index >= arr.low and index <= arr.high

proc first*[T](arr: openArray[T], condition: proc(t: T): bool): T =
  for t in arr:
    if condition(t):
      return t

