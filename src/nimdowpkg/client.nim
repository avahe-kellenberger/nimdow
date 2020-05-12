import
  x11/x,
  hashes

type
  Client* = ref object
    window*: TWindow
    isFullscreen*: bool

proc newClient*(window: TWindow): Client =
  Client(window: window, isFullscreen: false)

func find*(clients: seq[Client], window: TWindow): int =
  for i, client in clients:
    if client.window == window:
      return i
  return -1

proc hash*(this: Client): Hash = !$Hash(this.window) 
