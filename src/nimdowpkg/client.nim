import
  x11/x,
  options,
  hashes

type
  Client* = ref object
    window*: TWindow
    isFullscreen*: bool

proc newClient*(window: TWindow): Client =
  Client(window: window, isFullscreen: false)

func indexOf*(clients: seq[Client], window: TWindow): int =
  for i, client in clients:
    if client.window == window:
      return i
  return -1

proc hash*(this: Client): Hash = !$Hash(this.window) 
