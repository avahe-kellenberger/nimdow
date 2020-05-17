import
  x11/x,
  hashes

type
  Client* = ref object
    window*: TWindow
    borderWidth*: int
    isFullscreen*: bool
    isFloating*: bool

proc hash*(this: Client): Hash

proc newClient*(window: TWindow): Client =
  Client(
    window: window,
    borderWidth: 0,
    isFullscreen: false,
    isFloating: false
  )

proc isNormal*(this: Client): bool =
  ## If the client is "normal".
  ## This currently means the client is not floating.
  not this.isFloating

func find*(clients: seq[Client], window: TWindow): int =
  ## Finds a client's index by its relative window.
  ## If a client is not found, -1 is returned.
  for i, client in clients:
    if client.window == window:
      return i
  return -1

proc findNextNormal*(clients: openArray[Client], i: int = 0): int =
  ## Finds the next normal client index from index `i`, iterating forward.
  ## This search will loop the array.
  for j in countup(i + 1, clients.high):
    if clients[j].isNormal:
      return j
  for j in countup(clients.low, i - 1):
    if clients[j].isNormal:
      return j
  return -1

proc findPreviousNormal*(clients: openArray[Client], i: int): int =
  ## Finds the next normal client index from index `i`, iterating backward.
  ## This search will loop the array.
  for j in countdown(i - 1, clients.low):
    if clients[j].isNormal:
      return j
  for j in countdown(clients.high, i + 1):
    if clients[j].isNormal:
      return j
  return -1

proc hash*(this: Client): Hash = !$Hash(this.window) 

