import
  x11/x,
  sets,
  options,
  hashes

type
  Client* = ref object
    window*: TWindow
    isFullscreen*: bool

proc newClient*(window: TWindow): Client =
  Client(window: window, isFullscreen: false)

func find*(clients: OrderedSet[Client], window: TWindow): Option[Client] =
  for client in clients:
    if client.window == window:
      return some(client)
  return none(Client)

proc hash*(this: Client): Hash = !$Hash(this.window) 
